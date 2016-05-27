module Access
  class Core
    class << self

      # Get a hash with symbols, names, action words for the available levels.
      # @return [Hash]
      def levels
        {
            owner: {
                name: 'Owner',
                action: 'own'
            },
            writer: {
                name: 'Writer',
                action: 'write'
            },
            reader: {
                name: 'Reader',
                action: 'read'
            },
            none: {
                name: 'None',
                action: 'no'
            }
        }
      end

      def levels_allow
        [:reader, :writer, :owner]
      end

      def levels_deny
        [:none]
      end

      # Get a hash with symbols, names, action words for the available roles.
      # @return [Hash]
      def roles
        {
            admin: {
                name: 'Administrator',
                action: 'administer'
            },
            user: {
                name: 'User',
                action: 'use'
            },
            harvester: {
                name: 'Harvester',
                action: 'harvest'
            }
        }
      end

      # Get level display name.
      # @param [Symbol] key
      # @return [string] name
      def get_level_name(key)
        get_hash_value(levels, key, :name)
      end

      # Get level action word.
      # @param [Symbol] key
      # @return [string] action word
      def get_level_action(key)
        get_hash_value(levels, key, :action)
      end

      # Get role display name.
      # @param [Symbol] key
      # @return [string] name
      def get_role_name(key)
        get_hash_value(roles, key, :name)
      end

      # Get role action word.
      # @param [Symbol] key
      # @return [string] action word
      def get_role_action(key)
        get_hash_value(roles, key, :action)
      end

      # Get value from hash of symbols, names, and action words.
      # @param [Hash] hash
      # @param [Symbol] key
      # @param [Symbol] attribute
      # @return [string] value
      def get_hash_value(hash, key, attribute)
        hash[key][attribute]
      end

      # Validate access level.
      # @param [Object] level
      # @return [Symbol] level
      def validate_level(level)
        fail ArgumentError, 'Access level must not be blank.' if level.blank?

        valid_levels = levels.keys
        level_sym = level.to_sym

        fail ArgumentError, "Access level '#{level_sym}' is not in available levels '#{valid_levels}'." unless valid_levels.include?(level_sym)

        level_sym
      end

      # Validate array of access levels.
      # @param [Array<Symbol>] levels
      # @return [Array<Symbol>] levels
      def validate_levels(levels)
        fail ArgumentError, 'Access level array must not be blank.' if levels.blank?
        levels = [levels] unless levels.respond_to?(:map)

        levels_sym = levels.map { |i| validate_level(i) }.uniq
        validate_level_combination(levels_sym)
        levels_sym
      end

      # Validate level combination.
      # @param [Array<Symbol>] levels
      # @return [Array<Symbol>] levels
      def validate_level_combination(levels)
        if levels.respond_to?(:each)
          if (levels.include?(:none) || levels.include?('none')) && levels.size > 1
            # none cannot be with other levels because this can be ambiguous, and points to a problem with how the
            # permissions were obtained.
            fail ArgumentError, "Level array cannot contain none with other levels, got '#{levels.join(', ')}'."
          else
            levels
          end
        else
          fail ArgumentError, "Must be an array of levels, got '#{levels.class}'."
        end
      end

      # Validate Project.
      # @param [Project] project
      # @return [Project] project
      def validate_project(project)
        fail ArgumentError, "Project was not valid, got '#{project.class}'." if project.blank? || !project.is_a?(Project)
        project
      end

      # Validate Projects.
      # @param [Array<Project>] projects
      # @return [Array<Project>] projects
      def validate_projects(projects)
        fail ArgumentError, 'No projects provided.' if projects.blank?
        projects.to_a.map { |p| validate_project(p) }
      end

      # Validate User. User can be nil.
      # @param [User] user
      # @return [User] user
      def validate_user(user)
        fail ArgumentError, "User was not valid, got '#{user.class}'." if !user.blank? && !user.is_a?(User)
        user
      end

      # Validate Users. User can be nil.
      # @param [Array<User>] users
      # @return [Array<User>] users
      def validate_users(users)
        users.to_a.map { |u| validate_user(u) }
      end

      # Validate audio recording.
      # @param [AudioRecording] audio_recording
      # @return [AudioRecording] audio_recording
      def validate_audio_recording(audio_recording)
        fail ArgumentError, "AudioRecording was not valid, got '#{audio_recording.class}'." if audio_recording.blank? || !audio_recording.is_a?(AudioRecording)
        audio_recording
      end

      # Validate audio recordings.
      # @param [Array<AudioRecording>] audio_recordings
      # @return [Array<AudioRecording>] audio_recordings
      def validate_audio_recordings(audio_recordings)
        audio_recordings.to_a.map { |u| validate_audio_recording(u) }
      end

      # Validate audio event.
      # @param [AudioEvent] audio_event
      # @return [AudioEvent] audio_event
      def validate_audio_event(audio_event)
        fail ArgumentError, "AudioRecording was not valid, got '#{audio_event.class}'." if audio_event.blank? || !audio_event.is_a?(AudioEvent)
        audio_event
      end

      # Validate audio events.
      # @param [Array<AudioEvent>] audio_events
      # @return [Array<AudioEvent>] audio_events
      def validate_audio_events(audio_events)
        audio_events.to_a.map { |u| validate_audio_event(u) }
      end

      # Validate analysis job.
      # @param [Array<AnalysisJob>] analysis_job
      # @return [Array<AnalysisJob>] analysis_job
      def validate_analysis_job(analysis_job)
        fail ArgumentError, "AnalysisJob was not valid, got '#{analysis_job.class}'." if analysis_job.blank? || !analysis_job.is_a?(AnalysisJob)
        analysis_job
      end

      # Get an array of access levels that are equal or lower.
      # @param [Symbol] level
      # @return [Array<Symbol>]
      def equal_or_lower(level)
        level_sym = validate_level(level)
        case level_sym
          when :owner
            [:reader, :writer, :owner]
          when :writer
            [:reader, :writer]
          when :reader
            [:reader]
          when :none
            [:none]
          else
            fail ArgumentError, "Can not get equal or lower level for #{level}, must be one of #{values.keys.join(', ')}."
        end

      end

      # Get an array of access levels that are equal or greater.
      # @param [Symbol] level
      # @return [Array<Symbol>]
      def equal_or_greater(level)
        level_sym = validate_level(level)
        case level_sym
          when :owner
            [:owner]
          when :writer
            [:writer, :owner]
          when :reader
            [:reader, :writer, :owner]
          when :none
            [:none]
          else
            fail ArgumentError, "Can not get equal or greater level for #{level}, must be one of #{values.keys.join(', ')}."
        end
      end

      # Get the highest access level.
      # @param [Array<Symbol>] levels
      # @return [Symbol]
      def highest(levels)
        levels_sym = validate_levels(levels)

        return :owner if levels_sym.include?(:owner)
        return :writer if levels_sym.include?(:writer)
        return :reader if levels_sym.include?(:reader)
        :none if levels_sym.include?(:none)
      end

      # Get the lowest access level.
      # @param [Array<Symbol>] levels
      # @return [Symbol]
      def lowest(levels)
        levels_sym = validate_levels(levels)

        return :none if levels_sym.include?(:none)
        return :reader if levels_sym.include?(:reader)
        return :writer if levels_sym.include?(:writer)
        :owner if levels_sym.include?(:owner)
      end

    end
  end
end