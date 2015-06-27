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

      # Add project permission restrictions.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] modified query
      def query_project_access(user, levels, query)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

        if Access::Check.is_admin?(user)
          query
        elsif Access::Check.is_standard_user?(user)
          if levels == [:none]

            query
                .where(
                    '(NOT EXISTS (SELECT 1 FROM projects AS invert_pt WHERE invert_pt.creator_id = ?))',
                    user.id)
                .where(
                    '(NOT EXISTS (SELECT 1 FROM permissions AS invert_pm WHERE invert_pm.user_id = ? AND invert_pm.project_id = projects.id))',
                    user.id)

            # after adding logged_in and anonymous permissions.
            # query
            #     .where(
            #         '(NOT EXISTS (SELECT 1 FROM permissions invert_pm_logged_in WHERE invert_pm_logged_in.logged_in = TRUE AND invert_pm_logged_in.project_id = projects.id))')
            #     .where(
            #         '(NOT EXISTS (SELECT 1 FROM permissions invert_pm WHERE invert_pm.user_id = ? AND invert_pm.project_id = projects.id))',
            #         user.id)

          else

            # see http://jpospisil.com/2014/06/16/the-definitive-guide-to-arel-the-sql-manager-for-ruby.html

            # build up in Arel
            pt = Project.arel_table
            ae = AudioEvent.arel_table
            pm = Permission.arel_table

            # need to add the 'deleted_at IS NULL' check by hand
            projects_creator_fragment = pt.where(pt[:deleted_at].eq(nil)).where(pt[:creator_id].eq(user.id)).project(pt[:id])
            permissions_user_fragment = pm.where(pm[:user_id].eq(user.id)).where(pm[:level].in(levels)).project(pm[:project_id])
            condition_pt = pt[:id].in(projects_creator_fragment).or(pt[:id].in(permissions_user_fragment))

            # after adding logged_in and anonymous permissions.
            # permissions_user_fragment = Permission.where(user: user, level: levels, logged_in: false, anonymous: false).select(:project_id)
            # permissions_logged_in_fragment = Permission.where(user: nil, level: levels, logged_in: true, anonymous: false).select(:project_id)
            # condition_pt = pt[:id].in(permissions_logged_in_fragment.arel).or(pt[:id].in(permissions_user_fragment.arel))

            audio_event_reference_fragment = ae.where(ae[:deleted_at].eq(nil)).where(ae[:is_reference].eq(true)).project(ae[:id])
            condition_ae = ae[:id].in(audio_event_reference_fragment)

            # include reference audio_events when:
            # - query is for audio_events or audio_event_comments
            model_name = query.model.model_name.name
            check_reference_audio_events = model_name == 'AudioEvent' || model_name == 'AudioEventComment'

            if check_reference_audio_events
              query.where(condition_pt.or(condition_ae))
            else
              query.where(condition_pt)
            end

            #query
          end
        else
          is_guest = Access::Check.is_guest?(user)
          Rails.logger.warn "User '#{user.user_name}' (#{user.id}) who is#{is_guest ? '' : ' not'} a guest with roles '#{user.role_symbols.join(', ')}' has no access."

          # any other role has no access (using .none to be chain-able)
          query.none
        end

      end

    end
  end
end