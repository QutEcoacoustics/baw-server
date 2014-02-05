Time::DATE_FORMATS[:long_time] = '%H:%M:%S'
Time::DATE_FORMATS[:readable_full] = lambda { |time| time.strftime("%A, #{ActiveSupport::Inflector.ordinalize(time.day)} %B %Y at %H:%M:%S #{time.formatted_offset(false)}") }
Date::DATE_FORMATS[:month_and_year] = '%B %Y'
Date::DATE_FORMATS[:short_ordinal] = lambda { |date| date.strftime("%B #{date.day.ordinalize}") }