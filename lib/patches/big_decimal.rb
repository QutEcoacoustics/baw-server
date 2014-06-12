# http://stackoverflow.com/questions/6128794/rails-json-serialization-of-decimal-adds-quotes
# patch BigDecimal so json is output without quotes.
require 'bigdecimal'

class BigDecimal
  def as_json(options = nil) #:nodoc:
    if finite?
      self
    else
      NilClass::AS_JSON
    end
  end
end