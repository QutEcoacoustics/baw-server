# Be sure to restart your server when you modify this file.

# @see http://guides.rubyonrails.org/upgrading_ruby_on_rails.html#cookies-serializer
# this should be changed to :json at some point when most people have visited the site
# and their cookies have been updated.
Rails.application.config.action_dispatch.cookies_serializer = :hybrid

# ensure json does not serialise BigDecimal to a string in json
# this was added in Rails 4.1, removed Rails 4.2
#Rails.application.config.active_support.encode_big_decimal_as_string = false