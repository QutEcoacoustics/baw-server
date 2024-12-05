# frozen_string_literal: true

Time::DATE_FORMATS[:long_time] = '%H:%M:%S'
Time::DATE_FORMATS[:very_long_time] = '%H:%M:%S.%3N'
Time::DATE_FORMATS[:readable_very_long_time] = '%H hr %M min %S.%3N sec'
Time::DATE_FORMATS[:readable_full] = lambda { |time|
  time.strftime("%a, #{ActiveSupport::Inflector.ordinalize(time.day)} %b %Y at %H:%M:%S #{time.formatted_offset(false)}")
}
Time::DATE_FORMATS[:readable_full_without_seconds] = lambda { |time|
  time.strftime("%a, #{ActiveSupport::Inflector.ordinalize(time.day)} %b %Y at %H:%M (#{time.formatted_offset(true)})")
}
Date::DATE_FORMATS[:month_and_year] = '%B %Y'
Date::DATE_FORMATS[:short_ordinal] = ->(date) { date.strftime("%B #{date.day.ordinalize}") }
Time::DATE_FORMATS[:long_year] = '%Y/%m/%d'
