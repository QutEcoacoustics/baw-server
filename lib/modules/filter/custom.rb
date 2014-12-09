require 'active_support/concern'

module Filter

  # Provides custom filters for composing queries.
  module Custom
    extend ActiveSupport::Concern
    extend Comparison
    extend Core
    extend Subset
    extend Validate

    private

    # Build project creator condition.
    # @param [Integer] creator_id
    # @return [Arel::Nodes::Node] condition
    def compose_project_creator(creator_id)
      # creator_id_check = 'projects.creator_id = ?'
      compose_eq(relation_table(Project), :creator_id, [:creator_id], creator_id)
    end

    # Build project sign in level condition.
    # @param [Symbol] level
    # @return [Arel::Nodes::Node] condition
    def compose_project_sign_in_level(level)
      levels = AccessLevel.decompose(level).map {|l| l.to_s}
      # creator_id_check = 'projects.sign_in_level  IN ()'
      compose_in(relation_table(Project), :sign_in_level, [:sign_in_level], levels)
    end

    # Build project sign in level condition.
    # @param [Symbol] level
    # @return [Arel::Nodes::Node] condition
    def compose_project_anonymous_level(level)
      levels = AccessLevel.decompose(level).map {|l| l.to_s}
      # creator_id_check = 'projects.anonymous_level IN ()'
      compose_in(relation_table(Project), :anonymous_level, [:anonymous_level], levels)
    end

    # Build user permissions condition.
    # @param [Integer] user_id
    # @return [Arel::Nodes::Node] condition
    def compose_user_permissions(user_id, level)
      levels = AccessLevel.decompose(level).map {|l| l.to_s}
      # permissions_check = 'permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\')'
      user_permissions = compose_eq(relation_table(Permission), :user_id, [:user_id], user_id)
      permission_level = compose_in(relation_table(Permission), :level, [:level], levels)
      compose_and(user_permissions, permission_level)
    end

    # Build project creator condition.
    # @param [Boolean] is_reference
    # @return [Arel::Nodes::Node] condition
    def compose_audio_event_reference(is_reference)
      # reference_audio_event_check = 'audio_events.is_reference IS TRUE'
      compose_eq(relation_table(AudioEvent), :is_reference, [:is_reference], is_reference)
    end

    # Build permission check condition.
    # @param [Integer] user_id
    # @param [Boolean] is_reference
    # @param [Symbol] min_access_level
    # @return [Arel::Nodes::Node] condition
    def compose_permission_check(user_id, is_reference, min_access_level)
      level = AccessLevel.validate(min_access_level)
      # where("((#{creator_id_check}) OR (#{permissions_check}) OR (#{reference_audio_event_check}))", user.id, user.id)
      compose_or(
        compose_or(
            compose_or(
                compose_project_creator(user_id),
                compose_user_permissions(user_id, level)
            ),
            compose_audio_event_reference(is_reference)
        ),
        compose_project_sign_in_level(level)
      )
    end

    # Create SIMILAR TO condition for text.
    # @param [Arel::Table] table
    # @param [Symbol] column_name
    # @param [Array<Symbol>] text_allowed
    # @param [Array<String>] text_array
    # @return [Arel::Nodes::Node] condition
    def compose_similar(table, column_name, text_allowed, text_array)

      #tags_partial = CSV.parse(params[:tagsPartial], col_sep: ',').flatten.map { |item| item.trim(' ', '') }.join('|').downcase
      #tags_query = AudioEvent.joins(:tags).where('lower(tags.text) SIMILAR TO ?', "%(#{tags_partial})%").select('audio_events.id')

      validate_table_column(table, column_name, text_allowed)
      sanitized_value = text_array.map { |item| sanitize_similar_to_value(item.trim(' ', '')) }.join('|').downcase
      contains_value = "%(#{sanitized_value})%"
      lower_value = "lower(#{table.name}.#{column_name})"
      similar = "#{lower_value} SIMILAR TO #{contains_value}"

      Arel::Nodes::SqlLiteral.new(similar)
    end

    # Create distance projection.
    # @param [Float] freq_min
    # @param [Float] freq_max
    # @param [Float] annotation_duration
    # @return [Arel::Nodes::Node] projection
    def project_distance(freq_min, freq_max, annotation_duration)
      if !freq_min.blank? || !freq_max.blank? || !annotation_duration.blank?
        select_string = []

        unless freq_min.blank?
          validate_float(freq_min)
          select_string.push("power(audio_events.low_frequency_hertz - #{freq_min}, 2)")
        end

        unless freq_max.blank?
          validate_float(freq_max)
          select_string.push("power(audio_events.high_frequency_hertz - #{freq_max}, 2)")
        end

        unless annotation_duration.blank?
          validate_float(annotation_duration)
          select_string.push("power((audio_events.end_time_seconds - audio_events.start_time_seconds) - #{annotation_duration}, 2)")
        end

        sql = 'sqrt('+select_string.join(' + ')+') as distance_calc'

        Arel::Nodes::SqlLiteral.new(sql)
      else
        nil
      end
    end

  end
end