require 'jsonapi/formatter'
require 'jsonapi/processor'
require 'jsonapi/record_accessor'
require 'jsonapi/active_record_accessor'
require 'concurrent'

module JSONAPI
  class Configuration
    attr_reader :json_key_format,
                :resource_key_type,
                :route_format,
                :raise_if_parameters_not_allowed,
                :allow_include,
                :allow_sort,
                :allow_filter,
                :default_paginator,
                :default_page_size,
                :maximum_page_size,
                :default_record_accessor_klass,
                :default_processor_klass,
                :use_text_errors,
                :top_level_links_include_pagination,
                :top_level_meta_include_record_count,
                :top_level_meta_record_count_key,
                :top_level_meta_include_page_count,
                :top_level_meta_page_count_key,
                :allow_transactions,
                :include_backtraces_in_errors,
                :exception_class_whitelist,
                :whitelist_all_exceptions,
                :always_include_to_one_linkage_data,
                :always_include_to_many_linkage_data,
                :cache_formatters,
                :use_relationship_reflection,
                :resource_cache,
                :default_resource_cache_field,
                :resource_cache_digest_function,
                :resource_cache_usage_report_function

    def initialize
      #:underscored_key, :camelized_key, :dasherized_key, or custom
      self.json_key_format = :dasherized_key

      #:underscored_route, :camelized_route, :dasherized_route, or custom
      self.route_format = :dasherized_route

      #:integer, :uuid, :string, or custom (provide a proc)
      self.resource_key_type = :integer

      # optional request features
      self.allow_include = true
      self.allow_sort = true
      self.allow_filter = true

      self.raise_if_parameters_not_allowed = true

      # :none, :offset, :paged, or a custom paginator name
      self.default_paginator = :none

      # Output pagination links at top level
      self.top_level_links_include_pagination = true

      self.default_page_size = 10
      self.maximum_page_size = 20

      # Metadata
      # Output record count in top level meta for find operation
      self.top_level_meta_include_record_count = false
      self.top_level_meta_record_count_key = :record_count

      self.top_level_meta_include_page_count = false
      self.top_level_meta_page_count_key = :page_count

      self.use_text_errors = false

      # Whether or not to include exception backtraces in JSONAPI error
      # responses.  Defaults to `false` in production, and `true` otherwise.
      self.include_backtraces_in_errors = !Rails.env.production?

      # List of classes that should not be rescued by the operations processor.
      # For example, if you use Pundit for authorization, you might
      # raise a Pundit::NotAuthorizedError at some point during operations
      # processing. If you want to use Rails' `rescue_from` macro to
      # catch this error and render a 403 status code, you should add
      # the `Pundit::NotAuthorizedError` to the `exception_class_whitelist`.
      self.exception_class_whitelist = []

      # If enabled, will override configuration option `exception_class_whitelist`
      # and whitelist all exceptions.
      self.whitelist_all_exceptions = false

      # Resource Linkage
      # Controls the serialization of resource linkage for non compound documents
      # NOTE: always_include_to_many_linkage_data is not currently implemented
      self.always_include_to_one_linkage_data = false
      self.always_include_to_many_linkage_data = false

      # Record Accessor
      # The default Record Accessor is the ActiveRecordAccessor which provides
      # caching access to ActiveRecord backed models. Custom Accessors can be specified
      # in order to support other models.
      self.default_record_accessor_klass = JSONAPI::ActiveRecordAccessor

      # The default Operation Processor to use if one is not defined specifically
      # for a Resource.
      self.default_processor_klass = JSONAPI::Processor

      # Allows transactions for creating and updating records
      # Set this to false if your backend does not support transactions (e.g. Mongodb)
      self.allow_transactions = true

      # Formatter Caching
      # Set to false to disable caching of string operations on keys and links.
      # Note that unlike the resource cache, formatter caching is always done
      # internally in-memory and per-thread; no ActiveSupport::Cache is used.
      self.cache_formatters = true

      # Relationship reflection invokes the related resource when updates
      # are made to a has_many relationship. By default relationship_reflection
      # is turned off because it imposes a small performance penalty.
      self.use_relationship_reflection = false

      # Resource cache
      # An ActiveSupport::Cache::Store or similar, used by Resources with caching enabled.
      # Set to `nil` (the default) to disable caching, or to `Rails.cache` to use the
      # Rails cache store.
      self.resource_cache = nil

      # Default resource cache field
      # On Resources with caching enabled, this field will be used to check for out-of-date
      # cache entries, unless overridden on a specific Resource. Defaults to "updated_at".
      self.default_resource_cache_field = :updated_at

      # Resource cache digest function
      # Provide a callable that returns a unique value for string inputs with
      # low chance of collision. The default is SHA256 base64.
      self.resource_cache_digest_function = Digest::SHA2.new.method(:base64digest)

      # Resource cache usage reporting
      # Optionally provide a callable which JSONAPI will call with information about cache
      # performance. Should accept three arguments: resource name, hits count, misses count.
      self.resource_cache_usage_report_function = nil
    end

    def cache_formatters=(bool)
      @cache_formatters = bool
      if bool
        @key_formatter_tlv = Concurrent::ThreadLocalVar.new
        @route_formatter_tlv = Concurrent::ThreadLocalVar.new
      else
        @key_formatter_tlv = nil
        @route_formatter_tlv = nil
      end
    end

    def json_key_format=(format)
      @json_key_format = format
      if defined?(@cache_formatters)
        @key_formatter_tlv = Concurrent::ThreadLocalVar.new
      end
    end

    def route_format=(format)
      @route_format = format
      if defined?(@cache_formatters)
        @route_formatter_tlv = Concurrent::ThreadLocalVar.new
      end
    end

    def key_formatter
      if self.cache_formatters
        formatter = @key_formatter_tlv.value
        return formatter if formatter
      end

      formatter = JSONAPI::Formatter.formatter_for(self.json_key_format)

      if self.cache_formatters
        formatter = @key_formatter_tlv.value = formatter.cached
      end

      return formatter
    end

    def resource_key_type=(key_type)
      @resource_key_type = key_type
    end

    def route_formatter
      if self.cache_formatters
        formatter = @route_formatter_tlv.value
        return formatter if formatter
      end

      formatter = JSONAPI::Formatter.formatter_for(self.route_format)

      if self.cache_formatters
        formatter = @route_formatter_tlv.value = formatter.cached
      end

      return formatter
    end

    def exception_class_whitelisted?(e)
      @whitelist_all_exceptions ||
        @exception_class_whitelist.flatten.any? { |k| e.class.ancestors.map(&:to_s).include?(k.to_s) }
    end

    def default_processor_klass=(default_processor_klass)
      @default_processor_klass = default_processor_klass
    end

    def default_record_accessor_klass=(default_record_accessor_klass)
      @default_record_accessor_klass = default_record_accessor_klass
    end

    attr_writer :allow_include, :allow_sort, :allow_filter

    attr_writer :default_paginator

    attr_writer :default_page_size

    attr_writer :maximum_page_size

    attr_writer :use_text_errors

    attr_writer :top_level_links_include_pagination

    attr_writer :top_level_meta_include_record_count

    attr_writer :top_level_meta_record_count_key

    attr_writer :top_level_meta_include_page_count

    attr_writer :top_level_meta_page_count_key

    attr_writer :allow_transactions

    attr_writer :include_backtraces_in_errors

    attr_writer :exception_class_whitelist

    attr_writer :whitelist_all_exceptions

    attr_writer :always_include_to_one_linkage_data

    attr_writer :always_include_to_many_linkage_data

    attr_writer :raise_if_parameters_not_allowed

    attr_writer :use_relationship_reflection

    attr_writer :resource_cache

    attr_writer :default_resource_cache_field

    attr_writer :resource_cache_digest_function

    attr_writer :resource_cache_usage_report_function
  end

  class << self
    attr_accessor :configuration
  end

  @configuration ||= Configuration.new

  def self.configure
    yield(@configuration)
  end
end
