module Access

  # Methods for validating projects, levels, users, and other models.
  class Validate
    class << self

      # Validate access level, which can include empty or nil.
      # @param [Object] level
      # @return [Symbol] level
      def level(level)
        return nil if level.blank?
        level = level[0] if level.is_a?(Array) && level.size == 1
        case level.to_s
          when 'reader', 'read'
            :reader
          when 'writer', 'write'
            :writer
          when 'owner', 'own'
            :owner
          else
            valid_levels = Access::Core.levels.map(&:to_s)
            fail ArgumentError, "Access level '#{level.to_s}' is not in available levels '#{valid_levels}'."
        end
      end

      # Validate user role
      # @param [Object] role
      # @return [Symbol] role
      def role(role)
        role = role[0] if role.is_a?(Array) && role.size == 1
        valid_roles = Access::Core.roles.map(&:to_s)
        is_valid = !role.blank? && valid_roles.include?(role.to_s.to_sym)
        fail ArgumentError, "User role '#{role.to_s}' is not in available roles '#{valid_roles}'." unless is_valid

        role
      end

      # Validate array of access levels. No access is indicated using nil.
      # @param [Array<Symbol>] levels
      # @return [Array<Symbol>] levels
      def levels(levels)
        # need to keep nils, so don't remove them

        # flatten nested arrays
        levels = [levels].flatten

        # make array of levels unique and validate each
        # return the array of validated levels
        levels.uniq.map { |i| Access::Validate.level(i) }
      end

      # Validate Project.
      # @param [Project] project
      # @return [Project] project
      def project(project)
        fail ArgumentError, "Project was not valid, got '#{project.class}'." if project.blank? || !project.is_a?(Project)
        project
      end

      # Validate Projects.
      # @param [Array<Project>] projects
      # @return [Array<Project>] projects
      def projects(projects)
        fail ArgumentError, 'No projects provided.' if projects.blank?
        projects.to_a.flatten.map { |p| Access::Validate.project(p) }
      end

      # Validate User. User can be nil.
      # @param [User] user
      # @return [User] user
      def user(user, allow_nil = true)
        # need to check with #nil?, as #blank? executes a db query and guest users are not in db
        fail ArgumentError, "User was not valid, got '#{user.class}'." if !user.nil? && !user.respond_to?(:user_name)
        fail ArgumentError, 'User was not valid.' if !allow_nil && user.nil?
        user
      end

      # Validate Users. User can be nil.
      # @param [Array<User>] users
      # @return [Array<User>] users
      def users(users)
        users.to_a.map { |u| Access::Validate.user(u) }
      end

      # Validate audio recording.
      # @param [AudioRecording] audio_recording
      # @return [AudioRecording] audio_recording
      def audio_recording(audio_recording)
        fail ArgumentError, "AudioRecording was not valid, got '#{audio_recording.class}'." if audio_recording.blank? || !audio_recording.is_a?(AudioRecording)
        audio_recording
      end

      # Validate audio recordings.
      # @param [Array<AudioRecording>] audio_recordings
      # @return [Array<AudioRecording>] audio_recordings
      def audio_recordings(audio_recordings)
        audio_recordings.to_a.map { |u| Access::Validate.audio_recording(u) }
      end

      # Validate audio event.
      # @param [AudioEvent] audio_event
      # @return [AudioEvent] audio_event
      def audio_event(audio_event)
        fail ArgumentError, "AudioRecording was not valid, got '#{audio_event.class}'." if audio_event.blank? || !audio_event.is_a?(AudioEvent)
        audio_event
      end

      # Validate audio events.
      # @param [Array<AudioEvent>] audio_events
      # @return [Array<AudioEvent>] audio_events
      def audio_events(audio_events)
        audio_events.to_a.map { |u| Access::Validate.audio_event(u) }
      end
      
    end
  end
end