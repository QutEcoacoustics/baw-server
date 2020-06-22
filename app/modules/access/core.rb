# frozen_string_literal: true

# A module for applying access restrictions.
module Access
  # Basic level, user, and access methods.
  class Core
    class << self
      # Get a hash with symbols, names, action words for the available levels.
      # @return [Hash]
      def levels_hash
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
          }
        }
      end

      # Get all the valid levels.
      # @return [Array<Symbol>]
      def levels
        Access::Core.levels_hash.keys
      end

      # Get value indicating no access level.
      # @return [NilClass]
      def levels_none
        nil
      end

      # Get a hash with symbols, names, action words for the available roles.
      # @return [Hash]
      def roles_hash
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
          },
          guest: {
            name: 'Guest',
            action: 'use as guest'
          }
        }
      end

      # Get all the valid roles.
      # @return [Array<Symbol>]
      def roles
        User.valid_roles
      end

      # Get level display name.
      # @param [Symbol] key
      # @return [string] name
      def get_level_name(key)
        key = Access::Validate.level(key)
        get_hash_value(Access::Core.levels_hash, key, :name)
      end

      # Get level action word.
      # @param [Symbol] key
      # @return [string] action word
      def get_level_action(key)
        key = Access::Validate.level(key)
        get_hash_value(Access::Core.levels_hash, key, :action)
      end

      # Get role display name.
      # @param [Symbol] key
      # @return [string] name
      def get_role_name(key)
        key = Access::Validate.role(key)
        get_hash_value(Access::Core.roles_hash, key, :name)
      end

      # Get role action word.
      # @param [Symbol] key
      # @return [string] action word
      def get_role_action(key)
        key = Access::Validate.role(key)
        get_hash_value(Access::Core.roles_hash, key, :action)
      end

      # Get value from hash of symbols, names, and action words.
      # @param [Hash] hash
      # @param [Symbol] key
      # @param [Symbol] attribute
      # @return [string] value
      def get_hash_value(hash, key, attribute)
        hash[key][attribute]
      end

      # Normalise a level identifier.
      # @param [Object] level
      # @return [Symbol, nil] normalised level or nil
      def normalise_level(level)
        return nil if level.blank?

        case level.to_s
        when 'reader', 'read'
          :reader
        when 'writer', 'write'
          :writer
        when 'owner', 'own'
          :owner
          end
      end

      # Validate access level.
      # @param [Object] level
      # @return [Symbol] level
      def validate_level(level)
        raise ArgumentError, 'Access level must not be blank.' if level.blank?

        valid_levels = levels.keys
        level_sym = level.to_sym

        unless valid_levels.include?(level_sym)
          raise ArgumentError, "Access level '#{level_sym}' is not in available levels '#{valid_levels}'."
        end

        level_sym
      end

      # Validate array of access levels.
      # @param [Array<Symbol>] levels
      # @return [Array<Symbol>] levels
      def validate_levels(levels)
        raise ArgumentError, 'Access level array must not be blank.' if levels.blank?

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
            raise ArgumentError, "Level array cannot contain none with other levels, got '#{levels.join(', ')}'."
          else
            levels
          end
        else
          raise ArgumentError, "Must be an array of levels, got '#{levels.class}'."
        end
      end

      # Validate Project.
      # @param [Project] project
      # @return [Project] project
      def validate_project(project)
        if project.blank? || !project.is_a?(Project)
          raise ArgumentError, "Project was not valid, got '#{project.class}'."
        end

        project
      end

      # Validate Projects.
      # @param [Array<Project>] projects
      # @return [Array<Project>] projects
      def validate_projects(projects)
        raise ArgumentError, 'No projects provided.' if projects.blank?

        projects.to_a.map { |p| validate_project(p) }
      end

      # Validate User. User can be nil.
      # @param [User] user
      # @return [User] user
      def validate_user(user)
        raise ArgumentError, "User was not valid, got '#{user.class}'." if !user.blank? && !user.is_a?(User)

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
        if audio_recording.blank? || !audio_recording.is_a?(AudioRecording)
          raise ArgumentError, "AudioRecording was not valid, got '#{audio_recording.class}'."
        end

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
        if audio_event.blank? || !audio_event.is_a?(AudioEvent)
          raise ArgumentError, "AudioRecording was not valid, got '#{audio_event.class}'."
        end

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
        if analysis_job.blank? || !analysis_job.is_a?(AnalysisJob)
          raise ArgumentError, "AnalysisJob was not valid, got '#{analysis_job.class}'."
        end

        analysis_job
      end

      # Validate dataset.
      # @param [Array<Dataset>] dataset
      # @return [Array<Dataset>] dataset
      def validate_dataset(dataset)
        if dataset.blank? || !dataset.is_a?(Dataset)
          raise ArgumentError, "Dataset was not valid, got '#{dataset.class}'."
        end

        dataset
      end

      # Get an array of access levels that are equal or lower.
      # @param [Symbol] level
      # @return [Array<Symbol>]
      def equal_or_lower(level)
        level_sym = Access::Validate.level(level)
        case level_sym
        when :owner
          [:reader, :writer, :owner]
        when :writer
          [:reader, :writer]
        when :reader
          [:reader]
        else
          raise ArgumentError, "Can not get equal or lower level for '#{level}', must be one of #{Access::Core.levels.map(&:to_s).join(', ')}."
        end
      end

      # Get an array of access levels that are equal or greater.
      # @param [Symbol] level
      # @return [Array<Symbol>]
      def equal_or_greater(level)
        level_sym = Access::Validate.level(level)
        case level_sym
        when :owner
          [:owner]
        when :writer
          [:writer, :owner]
        when :reader
          [:reader, :writer, :owner]
        else
          raise ArgumentError, "Can not get equal or greater level for '#{level}', must be one of #{Access::Core.levels.map(&:to_s).join(', ')}."
        end
      end

      # Get the highest access level.
      # @param [Array<Symbol>] levels
      # @return [Symbol]
      def highest(levels)
        levels_sym = Access::Validate.levels(levels)

        return :owner if levels_sym.include?(:owner)
        return :writer if levels_sym.include?(:writer)
        return :reader if levels_sym.include?(:reader)

        nil
      end

      # Get the lowest access level.
      # @param [Array<Symbol>] levels
      # @return [Symbol]
      def lowest(levels)
        levels_sym = Access::Validate.levels(levels)

        return nil if Access::Core.is_no_level?(levels)
        return :reader if levels_sym.include?(:reader)
        return :writer if levels_sym.include?(:writer)

        :owner if levels_sym.include?(:owner)
      end

      # Check if these levels equate to no access level.
      # @param [Object] levels
      # @return [Boolean] true if is no access level, otherwise false
      def is_no_level?(levels)
        levels = Access::Validate.levels(levels)
        level = highest(levels)
        level.nil?
      end

      # Is this user an admin?
      # An admin is a user with the :admin role.
      # @param [User] user
      # @return [Boolean]
      def is_admin?(user)
        return false if Access::Core.is_guest?(user)

        user.has_role?(:admin)
      end

      # Is this user a guest?
      # A guest is a nil user or a user with the :guest role or a user without an id.
      # An unconfirmed user is not a guest user.
      # e.g. in some cases, current_user will be blank
      # e.g. for ability.rb, a user is created with role set as guest
      # @param [User] user
      # @return [Boolean]
      def is_guest?(user)
        Access::Validate.user(user)
        user.blank? || user.has_role?(:guest) || user.id.nil?
      end

      # Is this user an unconfirmed user?
      # An unconfirmed user has the :user role and has not confirmed their email.
      # NOT CURRENTLY USED.
      # @param [User] user
      # @return [Boolean]
      def is_unconfirmed_user?(user)
        return false if Access::Core.is_guest?(user)

        !user.confirmed?
      end

      # Is this user a standard user?
      # A standard user has the :user role.
      # @param [User] user
      # @return [Boolean]
      def is_standard_user?(user)
        return false if Access::Core.is_guest?(user)

        user.has_role?(:user)
      end

      # Is this user a harvester user?
      # A harvester user has the :harvester role.
      # @param [User] user
      # @return [Boolean]
      def is_harvester?(user)
        return false if Access::Core.is_guest?(user)

        user.has_role?(:harvester)
      end

      # Check if requested access level(s) is allowed based on actual access level(s).
      # If actual is a higher level than requested, it is allowed.
      # @param [Symbol, Array<Symbol>] requested_levels
      # @param [Symbol, Array<Symbol>] actual_levels
      # @return [Boolean]
      def allowed?(requested_levels, actual_levels)
        requested_array = Access::Validate.levels([requested_levels])
        actual_array = Access::Validate.levels([actual_levels])

        # short circuit checking nils
        return false if requested_array.blank? || requested_array.compact.blank? ||
                        actual_array.blank? || actual_array.compact.blank?

        actual_highest = Access::Core.highest(actual_array)
        actual_equal_or_lower = Access::Core.equal_or_lower(actual_highest)
        requested_highest = Access::Core.highest(requested_array)

        actual_equal_or_lower.include?(requested_highest)
      end

      # Does this user have this access level to this project?
      # @param [User] user
      # @param [Symbol] level
      # @param [Project] project
      # @return [Boolean]
      def can?(user, level, project)
        can_any?(user, level, [project])
      end

      # Does this user not have any access to this project?
      # @param [User] user
      # @param [Project] project
      # @return [Boolean]
      def cannot?(user, project)
        !can?(user, :reader, project)
      end

      # Does this user have this access level to any of these projects?
      # @param [User] user
      # @param [Symbol] level
      # @param [Array<Project>] projects
      # @return [Boolean]
      def can_any?(user, level, projects)
        requested_level = Access::Validate.level(level)
        actual_level = Access::Core.user_levels(user, projects)

        allowed?(requested_level, actual_level)
      end

      # Does this user not have any access to any of these projects?
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Boolean]
      def cannot_any?(user, projects)
        !can_any?(user, :reader, projects)
      end

      # Does this user have this access level to all of these projects?
      # @param [User] user
      # @param [Symbol] level
      # @param [Array<Project>] projects
      # @return [Boolean]
      def can_all?(user, level, projects)
        requested_level = Access::Validate.level(level)
        actual_levels = Access::Core.user_levels(user, projects)
        actual_level_lowest = Access::Core.lowest(actual_levels)

        allowed?(requested_level, actual_level_lowest)
      end

      # Does this user not have any access level to all of these projects?
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Boolean]
      def cannot_all?(user, projects)
        !can_all?(user, :reader, projects)
      end

      # Fail if the site is not in any projects.
      # @param [Site] site
      # @return [void]
      def check_orphan_site!(site)
        return if site.nil?

        if site.projects.empty?
          raise CustomErrors::OrphanedSiteError, "Site #{site.name} (#{site.id}) is not in any projects."
        end
      end

      # Get the access levels for this user to the project(s).
      # This method returns the access levels reflected in the permissions table,
      # so an admin may not have access to every project.
      # @param [User] user
      # @param [Project, Array<Project>] projects
      # @return [Array<Symbol, nil>]
      def user_levels(user, projects)
        # moved this case forward to shortcut project query execution
        return Access::Validate.levels([:owner]) if Access::Core.is_admin?(user)

        projects = Access::Validate.projects([projects])

        # always restricted to specified project(s)
        levels = Permission.where(project_id: projects)

        if Access::Core.is_guest?(user)
          # a guest user's permissions are only specified by :allow_logged_in
          levels = levels.where(user: nil, allow_logged_in: false, allow_anonymous: true)
        elsif !user.blank?
          # a logged in user can have their own permissions or
          # permissions specified by :allow_logged_in
          levels = levels.where('user_id = ? OR allow_logged_in IS TRUE', user.id)
        else
          raise ArgumentError, "Invalid user to retrieve levels: '#{user}'."
        end

        levels = levels.pluck(:level)
        Access::Validate.levels(levels)
      end

      # Get the access levels for this user to the project(s).
      # This method returns only individual user access levels reflected in the permissions table,
      # so an admin may not have access to every project.
      # @param [User] user
      # @param [Project, Array<Project>] projects
      # @return [Array<Symbol, nil>]
      def user_only_levels(user, projects)
        projects = Access::Validate.projects([projects])
        raise ArgumentError, 'Must provide a user, nil is not valid.' if Access::Core.is_guest?(user)

        levels = Permission
                 .where(project_id: projects)
                 .where('user_id = ?', user.id)
                 .pluck(:level)

        Access::Validate.levels(levels)
      end

      # Get the anonymous user access levels for this user to the project(s).
      # @param [Project, Array<Project>] projects
      # @return [Array<Symbol, nil>]
      def anon_levels(projects)
        user_levels(nil, projects)
      end

      # Get the access levels for logged in users to the project(s).
      # @param [Project, Array<Project>] projects
      # @return [Array<Symbol, nil>]
      def logged_in_levels(projects)
        projects = Access::Validate.projects([projects])

        levels = Permission
                 .where(project_id: projects)
                 .where('allow_logged_in IS TRUE')
                 .pluck(:level)

        Access::Validate.levels(levels)
      end
    end
  end
end
