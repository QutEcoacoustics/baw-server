# frozen_string_literal: true

class AudioRecording
  # just a spot to store verbose arel queries and expressions
  module ArelExpressions
    # An expression to return a dot-less extension based on the media type of the
    # audio recording. This is manually maintained list of media types
    # because postgresql doesn't know about mime types.
    # @return [::Arel::Nodes::Grouping]
    def media_type_to_extension_arel
      Arel::Nodes::Grouping.new(
        AudioRecording.arel_table[:media_type]
          .when('audio/x-wav').then('wav')
          .when('audio/wav').then('wav')
          .when('audio/flac').then('flac')
          .when('audio/x-flac').then('flac')
          .when('audio/mpeg').then('mp3')
          .when('audio/mp3').then('mp3')
          .when('audio/ogg').then('ogg')
          .when('audio/x-wv').then('wv')
          .when('audio/wavpack').then('wv')
          .when('audio/x-ms-wma').then('asf')
          .when('video/x-ms-asf').then('asf')
          .when('audio/webm').then('webm')
          .when('audio/aac').then('aac')
          .else('unknown')
      )
    end

    TIMEZONE_TABLE = Arel::Table.new('site_timezone')

    # An expression to return the timezone of the site for the current audio recording.
    # If the site's timezone is not set, then UTC is used.
    TIMEZONE_EXPRESSION = Arel.grouping(
      Site
      .arel_table
      .where(AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]))
      .project(Site.arel_table[:tzinfo_tz].coalesce('UTC').as('tzinfo_tz'))
      .ast
    )

    # An expression to return recorded_date in the site's timezone.
    RECORDED_DATE_IN_SITE_TIMEZONE_AREL = Arel::Nodes::InfixOperation.new(
      'AT TIME ZONE',
      Arel::Nodes::InfixOperation.new(
        'AT TIME ZONE',
        AudioRecording.arel_table[:recorded_date],
        Arel.quoted('UTC')
      ),
      TIMEZONE_TABLE[:tzinfo_tz]
    )

    BY_YEAR_AREL = Arel::Nodes::NamedFunction.new(
      'TO_CHAR',
      [
        TIMEZONE_TABLE
          .project(RECORDED_DATE_IN_SITE_TIMEZONE_AREL)
          .with(Arel::Nodes::As.new(TIMEZONE_TABLE, TIMEZONE_EXPRESSION)),
        Arel.quoted('YYYY')
      ]
    ).freeze

    BY_MONTH_AREL = Arel::Nodes::NamedFunction.new(
      'TO_CHAR',
      [
        TIMEZONE_TABLE
          .project(RECORDED_DATE_IN_SITE_TIMEZONE_AREL)
          .with(Arel::Nodes::As.new(TIMEZONE_TABLE, TIMEZONE_EXPRESSION)),
        Arel.quoted('YYYY-MM')
      ]
    ).freeze

    # An expression to return recorded_date in the site's timezone in our
    # standard filename compact format (no spaces, no dashes, no colons).
    # If the site's timezone is not set, then UTC is used.
    # Will shorten the offset to `Z` if it is `+0000`.
    # @return [::ArelExtensions::Nodes::Replace]
    def recorded_date_to_file_name_datestamp_arel
      # OK: postgresql does not support any type of date other than dates in
      # UTC or dates without a timezone (represented only in the current local
      # timezone). So we can't construct a date in the
      # site's timezone. Instead we have to get the date in the site's local
      # timezone (with no timezone information attached) and the offset
      # separately, and then squish the strings together. 🤦‍♂️
      # e.g.:
      # select
      # '2018-05-26T12:29:30'::timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Australia/Sydney',
      # '2018-05-26T12:29:30'::timestamp AT TIME ZONE 'UTC' - '2018-05-26T12:29:30'::timestamp AT TIME ZONE 'Australia/Sydney'

      # date in site's timezone
      datetime_part = RECORDED_DATE_IN_SITE_TIMEZONE_AREL

      # offset
      offset_part =
        Arel::Nodes::InfixOperation.new(
          'AT TIME ZONE',
          AudioRecording.arel_table[:recorded_date],
          Arel.quoted('UTC')
        ) - Arel::Nodes::InfixOperation.new(
          'AT TIME ZONE',
          AudioRecording.arel_table[:recorded_date],
          TIMEZONE_TABLE[:tzinfo_tz]
        )

      value =
        TIMEZONE_TABLE
          .project(
            Arel::Nodes::NamedFunction.new(
              'TO_CHAR',
              [datetime_part, Arel.quoted('YYYYMMDD"T"HH24MISS')]
            ).concat(
              Arel.quoted('+')
              .concat(
                Arel::Nodes::NamedFunction.new(
                  'TO_CHAR',
                  [offset_part, Arel.quoted('HH24MI')]
                )
              )
              .replace('+-', '-')
              .replace('+0000', 'Z')
            )
          )
          .with(Arel::Nodes::As.new(TIMEZONE_TABLE, TIMEZONE_EXPRESSION))
          .ast

      Arel.grouping(value)
    end

    # An expression to return a site's safe name for the current audio recording.
    # @param if_blank [String] the value to return if the site name is blank
    # @return [::Arel::Nodes::Node]
    def site_safe_name_arel(if_blank: nil)
      expression = Site
        .arel_table
        .project(Site::SAFE_NAME_AREL)
        .where(AudioRecording.arel_table[:site_id].eq(Site.arel_table[:id]))
        # convert select manager to a scalar subquery
        .ast

      if if_blank.present?
        expression = Arel::Nodes::NamedFunction.new(
          'COALESCE',
          [
            Arel::Nodes::NamedFunction.new(
              'NULLIF',
              [
                Arel::Nodes::Grouping.new(expression),
                Arel.quoted('')
              ]
            ),
            Arel.quoted(if_blank)
          ]
        )
      end

      expression
    end

    # An expression to return a friendly name for an audio recording.
    # @return [::Arel::Nodes::NamedFunction]
    def build_friendly_name_query
      Arel::Nodes::NamedFunction.new(
        'format',
        [
          # format string: datestamp, site name, audio recording id, extension
          Arel.quoted('%s_%s_%s.%s'),
          # date stamp
          recorded_date_to_file_name_datestamp_arel,
          # site name
          site_safe_name_arel(if_blank: 'NONAME'),
          # audio recording id
          AudioRecording.arel_table[:id].cast('text'),
          # extension
          media_type_to_extension_arel
        ]
      )
    end
  end
end
