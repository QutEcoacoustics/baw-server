# frozen_string_literal: true

# http://stackoverflow.com/questions/6128794/rails-json-serialization-of-decimal-adds-quotes
# patch BigDecimal so json is output without quotes.
# this was introduced in Rails 4.0 as `Rails.application.config.active_support.encode_big_decimal_as_string`
# it was removed in Rails 4.2 when the JSON encoder was rewritten
# https://github.com/rails/rails/commit/4d02296cfbd69b4d2757dfd20f23d778bb23b81b
# http://guides.rubyonrails.org/upgrading_ruby_on_rails.html#changes-in-json-handling
# https://github.com/rails/rails/pull/13060

require 'bigdecimal'

module  BawWeb
  module BigDecimal
    def as_json(_options = nil) #:nodoc:
      if finite?
        self
      else
        NilClass::AS_JSON
      end
    end

    def to_json(_options = nil) #:nodoc:
      if finite?
        to_s('F')
      else
        'null'
      end
    end
  end
end

BigDecimal.prepend BawWeb::BigDecimal
