module JSONAPI
  class Filter
    attr_accessor :filter

    def verify(values, context)
      values
    end

    def apply(records, value, _options)
      records.where(filter => value)
    end
  end
end
