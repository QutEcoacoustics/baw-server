module ModelCommon
  # @param [Hash] params
  # @param [Symbol] params_symbol
  # @param [Integer] min
  # @param [Integer] max
  def self.filter_count(params, params_symbol, min = 1, max)
    count = min
    if params.include?(params_symbol)
      count = params[params_symbol].to_i
    end

    if count < min
      count = min
    end

    if !max.blank? && count > max
      count = max
    end

    count
  end
end