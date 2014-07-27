class ApiRenderHelper
  def self.format_date_time(value)
    if value.respond_to?(:iso8601)
      value.iso8601(3) # 3 decimal places
    else
      value
    end
  end

  def self.to_f_or_i_or_s(v)
    # http://stackoverflow.com/questions/8071533/convert-input-value-to-integer-or-float-as-appropriate-using-ruby
    ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
  end
end