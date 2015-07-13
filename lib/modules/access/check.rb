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

      # Is this user a guest? A guest is a nil user object or unconfirmed user.
      # @param [User] user
      # @return [Boolean]
      def is_guest?(user)
        Access::Core.validate_user(user)
        user.blank? || !user.confirmed?
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
        requested_array = requested.respond_to?(:each) ? Access::Core.validate_levels(requested) : [Access::Core.validate_level(requested)]
        actual_array = actual.respond_to?(:each) ? Access::Core.validate_levels(actual) : [Access::Core.validate_level(actual)]

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

      # Does this user have this access level to any of these projects?
      # @param [User] user
      # @param [Symbol] level
      # @param [Array<Project>] projects
      # @return [Boolean]
      def can_any?(user, level, projects)
        requested_level = Access::Core.validate_level(level)
        actual_level = Access::Query.level_projects(user, projects)

        allowed?(requested_level, actual_level)
      end

      # Does this user have this access level to all of these projects?
      # @param [User] user
      # @param [Symbol] level
      # @param [Array<Project>] projects
      # @return [Boolean]
      def can_all?(user, level, projects)
        requested_level = Access::Core.validate_level(level)
        actual_level = Access::Query.level_projects_lowest(user, projects)

        allowed?(requested_level, actual_level)
      end

    end
  end
end