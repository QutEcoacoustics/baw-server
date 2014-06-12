# http://stackoverflow.com/questions/11743835/force-json-serialization-of-numbers-to-specific-precision/11750364#11750364
# enable Float to support specifying the precision when converting to json
require 'active_support/json' # gem install activesupport

class Float
  def as_json(options={})
    if options[:decimals]
      value = round(options[:decimals])
      (i=value.to_i) == value ? i : value
    else
      super
    end
  end
end