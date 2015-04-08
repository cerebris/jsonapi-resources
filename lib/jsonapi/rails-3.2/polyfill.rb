module ActionController
  class Base
    def self.action_on_unpermitted_parameters=(v)
      # no-op
    end
  end
end

# Rails 3.2 support for HTTP PATCH.
fail "Remove this patch" if Rails::VERSION::MAJOR > 3
# see http://weblog.rubyonrails.org/2012/2/26/edge-rails-patch-is-the-new-primary-http-method-for-updates/
# https://github.com/rails/rails/pull/505

# Be very conservative not to monkey-patch any methods until
# the relevant files are loaded.
ActiveSupport.on_load(:action_controller) do
  ActionDispatch::Request.instance_eval do
    # Is this a PATCH request?
    # Equivalent to <tt>request.request_method == :patch</tt>.
    def patch?
      HTTP_METHOD_LOOKUP[request_method] == :patch
    end
  end
  module ActionDispatch::Routing
    HTTP_METHODS << :patch unless HTTP_METHODS.include?(:patch)
  end
  ActionDispatch::Routing::Mapper::HttpHelpers.instance_eval do
    # Define a route that only recognizes HTTP PATCH.
    # For supported arguments, see <tt>Base#match</tt>.
    #
    # Example:
    #
    # patch 'bacon', :to => 'food#bacon'
    def patch(*args, &block)
      map_method(:patch, *args, &block)
    end
  end
  ActionDispatch::Integration::RequestHelpers.instance_eval do
    # Performs a PATCH request with the given parameters. See +#get+ for more
    # details.
    def patch(path, parameters = nil, headers = nil)
      process :patch, path, parameters, headers
    end

    # Performs a PATCH request, following any subsequent redirect.
    # See +request_via_redirect+ for more information.
    def patch_via_redirect(path, parameters = nil, headers = nil)
      request_via_redirect(:patch, path, parameters, headers)
    end
  end
  ActionDispatch::Integration::Runner.class_eval do
    %w(patch).each do |method|
define_method(method) do |*args|
        reset! unless integration_session
        # reset the html_document variable, but only for new get/post calls
        @html_document = nil unless method.in?(["cookies", "assigns"])
        integration_session.__send__(method, *args).tap do
          copy_session_variables!
        end
      end
    end
  end
  module ActionController::TestCase::Behavior
    def patch(action, parameters = nil, session = nil, flash = nil)
      process(action, parameters, session, flash, "PATCH")
    end
  end
  class ActionController::Responder
    ACTIONS_FOR_VERBS.update(:patch => :edit)
    delegate :patch?, :to => :request
  end
  ActionView::Helpers::FormHelper.instance_eval do
    # = Action View Form Helpers
    def apply_form_for_options!(record, object, options) #:nodoc:
      object = convert_to_model(object)

      as = options[:as]
      action, method = object.respond_to?(:persisted?) && object.persisted? ? [:edit, :patch] : [:new, :post]
      options[:html].reverse_merge!(
        :class  => as ? "#{action}_#{as}" : dom_class(object, action),
        :id     => as ? "#{action}_#{as}" : [options[:namespace], dom_id(object, action)].compact.join("_").presence,
        :method => method
      )

      options[:url] ||= polymorphic_path(record, :format => options.delete(:format))
    end
    private :apply_form_for_options!
  end
  module ActionDispatch::Routing::Mapper::Resources
    class SingletonResource
      def resource(*resources, &block)
        options = resources.extract_options!.dup

        if apply_common_behavior_for(:resource, resources, options, &block)
          return self
        end

        resource_scope(:resource, SingletonResource.new(resources.pop, options)) do
          yield if block_given?

          collection do
            post :create
          end if parent_resource.actions.include?(:create)

          new do
            get :new
          end if parent_resource.actions.include?(:new)

          member do
            get    :edit if parent_resource.actions.include?(:edit)
            get    :show if parent_resource.actions.include?(:show)
            if parent_resource.actions.include?(:update)
               # all that for this PATCH
               patch  :update
               put    :update
            end
            delete :destroy if parent_resource.actions.include?(:destroy)
          end
        end

        self
      end
    end
  end
end

class Hash

  # Returns a new hash with all keys converted using the block operation.
  #
  #  hash = { name: 'Rob', age: '28' }
  #
  #  hash.transform_keys{ |key| key.to_s.upcase }
  #  # => {"NAME"=>"Rob", "AGE"=>"28"}
  def transform_keys
    return enum_for(:transform_keys) unless block_given?
    result = self.class.new
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  # Destructively convert all keys using the block operations.
  # Same as transform_keys but modifies +self+.
  def transform_keys!
    return enum_for(:transform_keys!) unless block_given?
    keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  # Returns a new hash with all keys converted to strings.
  #
  #   hash = { name: 'Rob', age: '28' }
  #
  #   hash.stringify_keys
  #   # => {"name"=>"Rob", "age"=>"28"}
  def stringify_keys
    transform_keys{ |key| key.to_s }
  end

  # Destructively convert all keys to strings. Same as
  # +stringify_keys+, but modifies +self+.
  def stringify_keys!
    transform_keys!{ |key| key.to_s }
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  #
  #   hash = { 'name' => 'Rob', 'age' => '28' }
  #
  #   hash.symbolize_keys
  #   # => {:name=>"Rob", :age=>"28"}
  def symbolize_keys
    transform_keys{ |key| key.to_sym rescue key }
  end
  alias_method :to_options,  :symbolize_keys

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. Same as +symbolize_keys+, but modifies +self+.
  def symbolize_keys!
    transform_keys!{ |key| key.to_sym rescue key }
  end
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match <tt>*valid_keys</tt>, raising
  # ArgumentError on a mismatch.
  #
  # Note that keys are treated differently than HashWithIndifferentAccess,
  # meaning that string and symbol keys will not match.
  #
  #   { name: 'Rob', years: '28' }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: :years. Valid keys are: :name, :age"
  #   { name: 'Rob', age: '28' }.assert_valid_keys('name', 'age') # => raises "ArgumentError: Unknown key: :name. Valid keys are: 'name', 'age'"
  #   { name: 'Rob', age: '28' }.assert_valid_keys(:name, :age)   # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      unless valid_keys.include?(k)
        raise ArgumentError.new("Unknown key: #{k.inspect}. Valid keys are: #{valid_keys.map(&:inspect).join(', ')}")
      end
    end
  end

  # Returns a new hash with all keys converted by the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  #
  #  hash = { person: { name: 'Rob', age: '28' } }
  #
  #  hash.deep_transform_keys{ |key| key.to_s.upcase }
  #  # => {"PERSON"=>{"NAME"=>"Rob", "AGE"=>"28"}}
  def deep_transform_keys(&block)
    _deep_transform_keys_in_object(self, &block)
  end

  # Destructively convert all keys by using the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_transform_keys!(&block)
    _deep_transform_keys_in_object!(self, &block)
  end

  # Returns a new hash with all keys converted to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  #
  #   hash = { person: { name: 'Rob', age: '28' } }
  #
  #   hash.deep_stringify_keys
  #   # => {"person"=>{"name"=>"Rob", "age"=>"28"}}
  def deep_stringify_keys
    deep_transform_keys{ |key| key.to_s }
  end

  # Destructively convert all keys to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_stringify_keys!
    deep_transform_keys!{ |key| key.to_s }
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+. This includes the keys from the root hash
  # and from all nested hashes and arrays.
  #
  #   hash = { 'person' => { 'name' => 'Rob', 'age' => '28' } }
  #
  #   hash.deep_symbolize_keys
  #   # => {:person=>{:name=>"Rob", :age=>"28"}}
  def deep_symbolize_keys
    deep_transform_keys{ |key| key.to_sym rescue key }
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_symbolize_keys!
    deep_transform_keys!{ |key| key.to_sym rescue key }
  end

  private

  def _deep_transform_keys_in_object(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = _deep_transform_keys_in_object(value, &block)
      end
    when Array
      object.map {|e| _deep_transform_keys_in_object(e, &block) }
    else
      object
    end
  end

  def _deep_transform_keys_in_object!(object, &block)
    case object
    when Hash
      object.keys.each do |key|
        value = object.delete(key)
        object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
      end
      object
    when Array
      object.map! {|e| _deep_transform_keys_in_object!(e, &block)}
    else
      object
    end
  end
end
