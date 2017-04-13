module JSONAPI
  class Paginator
    def initialize(_params); end

    def apply(_relation, _order_options)
      # relation
    end

    def links_page_params(_options = {})
      # :nocov:
      {}
      # :nocov:
    end

    class << self
      def requires_record_count
        # :nocov:
        false
        # :nocov:
      end

      def paginator_for(paginator)
        paginator_class_name = "#{paginator.to_s.camelize}Paginator"
        paginator_class_name.safe_constantize if paginator_class_name
      end
    end
  end
end

class OffsetPaginator < JSONAPI::Paginator
  attr_reader :limit, :offset

  def initialize(params)
    parse_pagination_params(params)
    verify_pagination_params
  end

  def self.requires_record_count
    true
  end

  def apply(relation, _order_options)
    relation.offset(@offset).limit(@limit)
  end

  def links_page_params(options = {})
    record_count = options[:record_count]
    links_page_params = {}

    links_page_params['first'] = {
      'offset' => 0,
      'limit' => @limit
    }

    if @offset > 0
      previous_offset = @offset - @limit

      previous_offset = 0 if previous_offset < 0

      links_page_params['prev'] = {
        'offset' => previous_offset,
        'limit' => @limit
      }
    end

    next_offset = @offset + @limit

    unless next_offset >= record_count
      links_page_params['next'] = {
        'offset' => next_offset,
        'limit' => @limit
      }
    end

    if record_count
      last_offset = record_count - @limit

      last_offset = 0 if last_offset < 0

      links_page_params['last'] = {
        'offset' => last_offset,
        'limit' => @limit
      }
    end

    links_page_params
  end

  private

  def parse_pagination_params(params)
    if params.nil?
      @offset = 0
      @limit = JSONAPI.configuration.default_page_size
    elsif params.is_a?(ActionController::Parameters)
      validparams = params.permit(:offset, :limit)

      @offset = validparams[:offset] ? validparams[:offset].to_i : 0
      @limit = validparams[:limit] ? validparams[:limit].to_i : JSONAPI.configuration.default_page_size
    else
      raise JSONAPI::Exceptions::InvalidPageObject
    end
  rescue ActionController::UnpermittedParameters => e
    raise JSONAPI::Exceptions::PageParametersNotAllowed, e.params
  end

  def verify_pagination_params
    raise JSONAPI::Exceptions::InvalidPageValue.new(:limit, @limit) if @limit < 1

    if @limit > JSONAPI.configuration.maximum_page_size
      raise JSONAPI::Exceptions::InvalidPageValue.new(:limit, @limit, detail: 'Limit exceeds maximum page size of ' \
        "#{JSONAPI.configuration.maximum_page_size}.")
    end

    raise JSONAPI::Exceptions::InvalidPageValue.new(:offset, @offset) if @offset < 0
  end
end

class PagedPaginator < JSONAPI::Paginator
  attr_reader :size, :number

  def initialize(params)
    parse_pagination_params(params)
    verify_pagination_params
  end

  def self.requires_record_count
    true
  end

  def calculate_page_count(record_count)
    (record_count / @size.to_f).ceil
  end

  def apply(relation, _order_options)
    offset = (@number - 1) * @size
    relation.offset(offset).limit(@size)
  end

  def links_page_params(options = {})
    record_count = options[:record_count]
    page_count = calculate_page_count(record_count)

    links_page_params = {}

    links_page_params['first'] = {
      'number' => 1,
      'size' => @size
    }

    if @number > 1
      links_page_params['prev'] = {
        'number' => @number - 1,
        'size' => @size
      }
    end

    unless @number >= page_count
      links_page_params['next'] = {
        'number' => @number + 1,
        'size' => @size
      }
    end

    if record_count
      links_page_params['last'] = {
        'number' => page_count.zero? ? 1 : page_count,
        'size' => @size
      }
    end

    links_page_params
  end

  private

  def parse_pagination_params(params)
    if params.nil?
      @number = 1
      @size = JSONAPI.configuration.default_page_size
    elsif params.is_a?(ActionController::Parameters)
      validparams = params.permit(:number, :size)

      @size = validparams[:size] ? validparams[:size].to_i : JSONAPI.configuration.default_page_size
      @number = validparams[:number] ? validparams[:number].to_i : 1
    else
      @size = JSONAPI.configuration.default_page_size
      @number = params.to_i
    end
  rescue ActionController::UnpermittedParameters => e
    raise JSONAPI::Exceptions::PageParametersNotAllowed, e.params
  end

  def verify_pagination_params
    raise JSONAPI::Exceptions::InvalidPageValue.new(:size, @size) if @size < 1

    if @size > JSONAPI.configuration.maximum_page_size
      raise JSONAPI::Exceptions::InvalidPageValue.new(:size, @size, detail: 'size exceeds maximum page size of ' \
        "#{JSONAPI.configuration.maximum_page_size}.")
    end

    raise JSONAPI::Exceptions::InvalidPageValue.new(:number, @number) if @number < 1
  end
end
