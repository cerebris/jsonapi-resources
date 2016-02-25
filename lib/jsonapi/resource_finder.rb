module JSONAPI
  module ResourceFinder
    def self.included(base)
      base.class_eval do
        base.extend ClassMethods
      end
    end

    module ClassMethods
      attr_accessor :_allowed_filters, :_paginator

      def inherited(subclass)
        super(subclass)
        subclass._allowed_filters = (_allowed_filters || Set.new).dup
      end


      def _table_name
        @_table_name ||= _model_class.respond_to?(:table_name) ? _model_class.table_name : _model_name.tableize
      end

      def apply_includes(records, options = {})
        include_directives = options[:include_directives]
        if include_directives
          model_includes = resolve_relationship_names_to_relations(self, include_directives.model_includes, options)
          records = records.includes(model_includes)
        end

        records
      end

      def _allowed_filters
        !@_allowed_filters.nil? ? @_allowed_filters : { id: {} }
      end

      def _allowed_filter?(filter)
        !_allowed_filters[filter].nil?
      end

      def _paginator
        @_paginator ||= :none
      end

      def paginator(paginator)
        @_paginator = paginator
      end

      def filters(*attrs)
        @_allowed_filters.merge!(attrs.inject({}) { |h, attr| h[attr] = {}; h })
      end

      def filter(attr, *args)
        @_allowed_filters[attr.to_sym] = args.extract_options!
      end

      # Either add a custom :verify labmda or override verify_custom_filter to allow for custom filters
      def verify_custom_filter(filter, value, _context = nil)
        [filter, value]
      end

      # Either add a custom :verify labmda or override verify_relationship_filter to allow for custom
      # relationship logic, such as uuids, multiple keys or permission checks on keys
      def verify_relationship_filter(filter, raw, _context = nil)
        [filter, raw]
      end

      # Override this method if you have more complex requirements than this basic find method provides
      def find(filters, options = {})
        context = options[:context]

        records = filter_records(filters, options)

        sort_criteria = options.fetch(:sort_criteria) { [] }
        records = apply_sort(records, options)

        records = apply_pagination(records, options)

        resources = []
        records.each do |model|
          resources.push self.resource_for_model(model).new(model, context)
        end

        resources
      end

      def find_by_key(key, options = {})
        context = options[:context]
        records = records(options)
        records = apply_includes(records, options)
        model = records.where({_primary_key => key}).first
        fail Railsapi::Exceptions::RecordNotFound.new(key) if model.nil?
        self.resource_for_model(model).new(model, context)
      end

      # Override this method if you want to customize the relation for
      # finder methods (find, find_by_key)
      def records(_options = {})
        _model_class.all
      end

      def apply_pagination(records, options = {})
        paginator = options[:paginator]
        if paginator
          records = paginator.apply(records, options)
        end
        records
      end

      def construct_order_options(sort_params)
        return {} unless sort_params

        sort_params.each_with_object({}) do |sort, order_hash|
          field = sort[:field] == 'id' ? _primary_key : sort[:field]
          order_hash[field] = sort[:direction]
        end
      end

      def apply_sort(records, options = {})
        order_options = construct_order_options(options[:sort_criteria])

        if order_options.any?
          records.order(order_options)
        else
          records
        end
      end

      def apply_filter(records, filter, value, options = {})
        strategy = _allowed_filters.fetch(filter.to_sym, Hash.new)[:apply]

        if strategy
          if strategy.is_a?(Symbol) || strategy.is_a?(String)
            send(strategy, records, value, options)
          else
            strategy.call(records, value, options)
          end
        else
          records.where(filter => value)
        end
      end

      def apply_filters(records, options = {})
        filters = options[:filters]

        if filters
          required_includes = []

          filters.each do |filter, value|
            if _relationships.include?(filter)
              if _relationships[filter].belongs_to?
                records = apply_filter(records, _relationships[filter].foreign_key, value, options)
              else
                required_includes.push(filter.to_s)
                records = apply_filter(records, "#{_relationships[filter].table_name}.#{_relationships[filter].primary_key}", value, options)
              end
            else
              records = apply_filter(records, filter, value, options)
            end
          end

          if required_includes.any?
            records = apply_includes(records, options.merge(include_directives: IncludeDirectives.new(required_includes)))
          end

        end
        records
      end

      def filter_records(filters, options, records = records(options))
        options[:filters] = filters
        records = apply_filters(records, options)
        apply_includes(records, options)
      end

      def find_count(filters, options = {})
        filter_records(filters, options).count(:all)
      end

      def verify_filters(filters, context = nil)
        verified_filters = {}
        filters.each do |filter, raw_value|
          verified_filter = verify_filter(filter, raw_value, context)
          verified_filters[verified_filter[0]] = verified_filter[1]
        end
        verified_filters
      end

      def is_filter_relationship?(filter)
        filter == _type || _relationships.include?(filter)
      end

      def verify_filter(filter, raw, context = nil)
        filter_values = []
        filter_values += CSV.parse_line(raw) unless raw.nil? || raw.empty?

        strategy = _allowed_filters.fetch(filter, Hash.new)[:verify]

        if strategy
          if strategy.is_a?(Symbol) || strategy.is_a?(String)
            values = send(strategy, filter_values, context)
          else
            values = strategy.call(filter_values, context)
          end
          [filter, values]
        else
          if is_filter_relationship?(filter)
            verify_relationship_filter(filter, filter_values, context)
          else
            verify_custom_filter(filter, filter_values, context)
          end
        end
      end
    end
  end
end
