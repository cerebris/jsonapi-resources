module JSONAPI
  class Paginator
    def initialize(params)
    end

    def apply(relation, order_options)
      # relation
    end

    class << self
      def paginator_for(paginator)
        paginator_class_name = "#{paginator.to_s.camelize}Paginator"
        paginator_class_name.safe_constantize if paginator_class_name
      end
    end
  end
end

class OffsetPaginator < JSONAPI::Paginator
  def initialize(params)
    parse_pagination_params(params)
    verify_pagination_params
  end

  def apply(relation, order_options)
    relation.offset(@offset).limit(@limit)
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
      raise JSONAPI::Exceptions::InvalidPageObject.new
    end
  rescue ActionController::UnpermittedParameters => e
    raise JSONAPI::Exceptions::PageParametersNotAllowed.new(e.params)
  end

  def verify_pagination_params
    if @limit < 1
      raise JSONAPI::Exceptions::InvalidPageValue.new(:limit, @limit)
    elsif @limit > JSONAPI.configuration.maximum_page_size
      raise JSONAPI::Exceptions::InvalidPageValue.new(:limit, @limit,
        "Limit exceeds maximum page size of #{JSONAPI.configuration.maximum_page_size}.")
    end

    if @offset < 0
      raise JSONAPI::Exceptions::InvalidPageValue.new(:offset, @offset)
    end
  end
end

class PagedPaginator < JSONAPI::Paginator
  def initialize(params)
    parse_pagination_params(params)
    verify_pagination_params
  end

  def apply(relation, order_options)
    offset = (@number - 1) * @size
    relation.offset(offset).limit(@size)
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
    raise JSONAPI::Exceptions::PageParametersNotAllowed.new(e.params)
  end

  def verify_pagination_params
    if @size < 1
      raise JSONAPI::Exceptions::InvalidPageValue.new(:size, @size)
    elsif @size > JSONAPI.configuration.maximum_page_size
      raise JSONAPI::Exceptions::InvalidPageValue.new(:size, @size,
        "size exceeds maximum page size of #{JSONAPI.configuration.maximum_page_size}.")
    end

    if @number < 1
      raise JSONAPI::Exceptions::InvalidPageValue.new(:number, @number)
    end
  end
end
