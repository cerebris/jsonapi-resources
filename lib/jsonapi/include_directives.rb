module JSONAPI
  class IncludeDirectives
    # Construct an IncludeDirectives Hash from an array of dot separated include strings.
    # For example ['posts.comments.tags']
    # will transform into =>
    # {
    #   posts:{
    #     include:true,
    #     include_linkage: {},
    #     include_related:{
    #       comments:{
    #         include:true,
    #         include_linkage: {},
    #         include_related:{
    #           tags:{
    #             include:true
    #           }
    #         }
    #       }
    #     }
    #   }
    # }

    def initialize(resource_klass, includes_array, force_eager_load: false)
      @resource_klass = resource_klass
      @force_eager_load = force_eager_load
      @include_directives_hash = { include_related: {}, include_linkage: get_include_linkage(@resource_klass) }
      includes_array.each do |include|
        parse_include(include)
      end
    end

    def include_directives
      @include_directives_hash
    end

    def model_includes
      get_includes(@include_directives_hash)
    end

    # :nocov:
    def all_paths
      delve_paths(get_includes(@include_directives_hash, false))
    end
    # :nocov:

    private

    def get_related(current_path)
      current = @include_directives_hash
      current_resource_klass = @resource_klass

      current_path.split('.').each do |path_fragment|
        path_fragment = path_fragment.to_sym

        if current_resource_klass
          current_relationship = current_resource_klass._relationships[path_fragment]
          current_resource_klass = current_relationship.try(:resource_klass)
        else
          raise JSONAPI::Exceptions::InvalidInclude.new(current_resource_klass, current_path)
        end

        include_in_join = @force_eager_load || !current_relationship || current_relationship.eager_load_on_include

        if current_relationship && current_relationship.polymorphic?
          include_linkage = {}
          current_relationship.polymorphic_resource_klasses.each do |related_polymorphic_klass|
            include_linkage[related_polymorphic_klass._type.to_s.singularize.to_sym] = get_include_linkage(related_polymorphic_klass)
          end
        else
          include_linkage = get_include_linkage(current_resource_klass)
        end

        current[:include_related][path_fragment] ||= {
            include: false,
            include_linkage: include_linkage,
            include_related: {},
            include_in_join: include_in_join
        }
        current = current[:include_related][path_fragment]
      end
      current
    end

    def get_include_linkage(resource_klass)
      include_linkage = {}
      return include_linkage unless resource_klass

      resource_klass._relationships.each_value do |relationship|
        if resource_klass.include_additional_relationship_linkage_data?(relationship.name)
          include_linkage[relationship.name.to_sym] = {}
        end
      end

      include_linkage
    end

    def get_includes(directive, only_joined_includes = true)
      ir = directive[:include_related]
      ir = ir.select { |_k,v| v[:include_in_join] } if only_joined_includes

      ir.map do |name, sub_directive|
        sub = get_includes(sub_directive, only_joined_includes)
        sub.any? ? { name => sub } : name
      end
    end

    def parse_include(include)
      parts = include.split('.')
      local_path = ''

      parts.each do |name|
        local_path += local_path.length > 0 ? ".#{name}" : name
        related = get_related(local_path)
        related[:include] = true
      end
    end

    # :nocov:
    def delve_paths(obj)
      case obj
        when Array
          obj.map{|elem| delve_paths(elem)}.flatten(1)
        when Hash
          obj.map{|k,v| [[k]] + delve_paths(v).map{|path| [k] + path } }.flatten(1)
        when Symbol, String
          [[obj]]
        else
          raise "delve_paths cannot descend into #{obj.class.name}"
      end
    end
    # :nocov:

  end
end
