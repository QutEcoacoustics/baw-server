module Access
  class Check
    class << self

      # Is this user an admin?
      # @param [User] user
      # @return [Boolean]
      def is_admin?(user)
        return false if is_guest?(user)
        user.has_role?(:admin)
      end

      # Is this user a guest?
      # A guest is nil or a user object assigned as a guest.
      # @param [User] user
      # @return [Boolean]
      def is_guest?(user)
        Access::Core.validate_user(user)
        # in some cases, current_user will be blank
        # for ability.rb, a user is created with role set as guest
        user.blank? || user.has_role?(:guest)
      end

      # Is this user a standard user?
      # @param [User] user
      # @return [Boolean]
      def is_standard_user?(user)
        return false if is_guest?(user)
        user.has_role?(:user)
      end

      # Is this user a harvester user?
      # @param [User] user
      # @return [Boolean]
      def is_harvester?(user)
        return false if is_guest?(user)
        user.has_role?(:harvester)
      end

      # Check if requested access level(s) is allowed based on actual access level(s).
      # If actual is a higher level than requested, it is allowed.
      # @param [Symbol, Array<Symbol>] requested
      # @param [Symbol, Array<Symbol>] actual
      # @return [Boolean]
      def allowed?(requested, actual)
        requested_array = Access::Core.validate_levels([requested])
        actual_array = Access::Core.validate_levels([actual])

        # short circuit checking nils
        return false if requested_array.blank? || actual_array.blank?

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
        requested_level = Access::Core.validate_level(level)
        actual_level = Access::Level.all(user, projects)

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
        requested_level = Access::Core.validate_level(level)
        actual_levels = Access::Level.all(user, projects)
        lowest_actual_level = Access::Core.lowest(actual_levels)

        allowed?(requested_level, lowest_actual_level)
      end

      # Does this user not have any access level to all of these projects?
      # @param [User] user
      # @param [Array<Project>] projects
      # @return [Boolean]
      def cannot_all?(user, projects)
        !can_all?(user, :reader, projects)
      end

    end
  end
end