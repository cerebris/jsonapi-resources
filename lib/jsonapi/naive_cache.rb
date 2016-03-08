module JSONAPI
  class NaiveCache
    def initialize(cap = 1024, &calculator)
      @data = {}
      @cap = cap
      @calculator = calculator
    end

    def calc(key)
      value = @data.fetch(key, nil)
      return value unless value.nil?
      value = @calculator.call(key)
      raise "Cannot cache nil value (calculated for #{key})" if value.nil?
      @data[key] = value
      @data.shift if @data.length > @cap
      return value
    end
  end
end
