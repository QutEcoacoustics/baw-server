class AccessLevel

  class << self
    # =====================================
    # access level hash
    # =====================================

    # Get a hash with display and description for the available access levels.
    # @return [Hash]
    def values
      {
          owner: {
              display: 'Owner',
              description: 'has owner permission to the project'
          },
          writer: {
              display: 'Writer',
              description: 'has write permission to the project'
          },
          reader: {
              display: 'Reader',
              description: 'has read permission to the project'
          },
          none: {
              display: 'None',
              description: 'has no permissions to the project'
          }
      }
    end

    def permission_all
      values.keys
    end

    # Permission levels as symbols (except :none).
    # @return [Array<Symbol>] levels
    def permission_symbols
      [:reader, :writer, :owner]
    end

    # Permission levels as strings (except none).
    # @return [Array<String>] levels
    def permission_strings
      %w(reader writer owner)
    end

    # Convert an access level to a string and check it is valid.
    # @param [Object] level
    # @return [String]
    def obj_to_str(level)
      value_sym = validate_level(level)
      value_sym.to_s
    end

    # Convert an access level to its display value.
    # @param [Object] level
    # @return [String]
    def obj_to_display(level)
      value_sym = validate_level(level)
      values[value_sym][:display]
    end

    # Convert an access level to its description.
    # @param [Object] value
    # @return [String]
    def obj_to_description(value)
      value_sym = validate_level(value)
      values[value_sym][:description]
    end

    # check if requested access level(s) is allowed based on actual access level(s).
    # If actual is a higher level than requested, it is allowed.
    # @param [Symbol, Array<Symbol>] requested
    # @param [Symbol, Array<Symbol>] actual
    # @return [Boolean]
    def is_allowed?(requested, actual)
      requested_array = requested.is_a?(Array) ? validate_levels(requested) : [validate_level(requested)]
      actual_array = actual.is_a?(Array) ? validate_levels(actual) : [validate_level(actual)]

      actual_highest = highest(actual_array)
      actual_equal_or_lower = equal_or_lower(actual_highest)

      requested_highest = highest(requested_array)
      actual_equal_or_lower.include?(requested_highest)
    end

    # Validate array of access levels.
    # @param [Array<Symbol>] levels
    # @return [void]
    def validate_levels(levels)
      fail ArgumentError, 'Access level array must not be blank.' if levels.blank?
      if levels.respond_to?(:each)
        levels_sym = levels.map { |i| validate_level(i) }.uniq
        validate_level_combination(levels_sym)
        levels_sym
      else
        fail ArgumentError, "Must be an array of symbols, got '#{levels.class}'."
      end
    end

    def validate_level_combination(levels)
      if levels.respond_to?(:each)
        if (levels.include?(:none) || levels.include?('none')) && levels.size > 1
          # none cannot be with other levels because this can be ambiguois, and points to a problem with how the
          # permissions were obtained.
          fail ArgumentError, "Level array cannot contain none with other levels, got '#{levels.join(', ')}'."
        end
      else
        fail ArgumentError, "Must be an array of symbols, got '#{levels.class}'."
      end
    end

    # Validate access level.
    # @param [Object] level
    # @return [void]
    def validate_level(level)
      fail ArgumentError, 'Access level must not be blank.' if level.blank?
      valid = values.keys
      value_sym = level.to_sym
      fail ArgumentError, "Access level '#{level}' is not in available levels '#{valid}'." unless valid.include?(value_sym)

      value_sym
    end

    def validate_project(project)
      fail ArgumentError, "Project was not valid, got '#{project.class}'." if project.blank? || !project.is_a?(Project)
    end

    def validate_user(user)
      # user can be nil
      fail ArgumentError, "User was not valid, got '#{user.class}'." if !user.blank? && !user.is_a?(User)
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
      return :none if levels_sym.include?(:none)
    end

    # Get the lowest access level.
    # @param [Array<Symbol>] levels
    # @return [Symbol]
    def lowest(levels)
      levels_sym = validate_levels(levels)

      return :none if levels_sym.include?(:none)
      return :reader if levels_sym.include?(:reader)
      return :writer if levels_sym.include?(:writer)
      return :owner if levels_sym.include?(:owner)
    end

    # Get access level for anonymous users for this project.
    # @param [Project] project
    # @return [Symbol] level
    def level_anonymous(project)
      validate_project(project)

      levels = Permission
                   .where(project_id: project.id, user_id: nil, logged_in_user: false, anonymous_user: true)
                   .pluck(:level)
      if levels.size > 1
        fail ActiveRecord::RecordNotUnique, "Found more than one permission matching project #{project.id}, anonymous user: true."
      elsif levels.size < 1
        :none
      else
        levels[0].to_sym
      end
    end

    # Get access level for logged in users for this project.
    # @param [Project] project
    # @return [Symbol] level
    def level_logged_in(project)
      validate_project(project)

      levels = Permission
                   .where(project_id: project.id, user_id: nil, logged_in_user: true, anonymous_user: false)
                   .pluck(:level)
      if levels.size > 1
        fail ActiveRecord::RecordNotUnique, "Found more than one permission matching project #{project.id}, logged in user: true."
      elsif levels.size < 1
        :none
      else
        levels[0].to_sym
      end
    end

    # Get access level for this user for this project (only checks Permission).
    # @param [User] user
    # @param [Project] project
    # @return [Symbol] level
    def level_user(user, project)
      validate_project(project)
      validate_user(user)

      levels = Permission
                   .where(project_id: project.id, user_id: user.id, logged_in_user: false, anonymous_user: false)
                   .pluck(:level)
      if levels.size > 1
        fail ActiveRecord::RecordNotUnique, "Found more than one permission matching project #{project.id}, user #{user.id}."
      elsif levels.size < 1
        :none
      else
        levels[0].to_sym
      end
    end

    # Get access level for this user for this project (checks anon, logged in, permission, user role).
    def level(user, project)
      validate_project(project)
      validate_user(user)

      if is_guest?(user)
        # check for guest first, since user can be nil
        # only anonymous permissions apply
        level_anonymous(project)
      elsif is_admin?(user)
        # admin has owner permission to all projects
        :owner
      else
        user_permission = level_user(user, project)
        logged_in_permission = level_logged_in(project)
        permissions = [user_permission, logged_in_permission]

        # this is necessary as :none and other levels can't be in the same array.
        # if other permissions are present, including :none doesn't make any sense.
        if permissions.include?(:none)
          permissions = permissions - [:none]
          return :none if permissions.size < 1
        end

        highest(permissions)
      end
    end

    # Get access level for this user for this project (checks anon, logged in, permission, user role).
    # Does no db queries.
    def manual_level(user, project, anonymous_level, logged_in_level)
      validate_project(project)
      validate_user(user)
      anonymous_level_sym = validate_level(anonymous_level)
      logged_in_level_sym = validate_level(logged_in_level)

      if is_guest?(user)
        anonymous_level_sym
      elsif is_admin?(user)
        :owner
      else
        user_permission = user.permissions
                              .select { |permission| permission.project_id == project.id }
                              .map { |permission| permission.level }

        if user_permission.size > 0
          highest(user_permission)
        else
          logged_in_level_sym
        end
      end

    end

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
      validate_user(user)
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

    # Does this user have this access level to this project?
    # @param [User] user
    # @param [Project] project
    # @param [Symbol] level
    # @return [Boolean]
    def access?(user, project, level)
      requested_level = validate_level(level)
      actual_level = level(user, project)

      is_allowed?(requested_level, actual_level)
    end

    # Does this user have this access level to any of these projects?
    # @param [User] user
    # @param [Array<Project>] projects
    # @param [Symbol] level
    # @return [Boolean]
    def access_any?(user, projects, level)
      projects.each do |project|
        return true if access?(user, project, level)
      end
      false
    end

    # Does this user have this access level to all of these projects?
    # @param [User] user
    # @param [Array<Project>] projects
    # @param [Symbol] level
    # @return [Boolean]
    def access_all?(user, projects, level)
      projects.each do |project|
        return false unless access?(user, project, level)
      end
      true
    end

    # All projects that this user has at least this access level for.
    # @param [User] user
    # @param [Symbol] level
    # @return [ActiveRecord::Relation]
    def projects(user, level)
      validate_user(user)
      level_sym = validate_level(level)
      equal_or_greater_levels = equal_or_greater(level_sym)

      order_clause = 'lower(projects.name) DESC'

      query =
          Project
              .includes(:permissions, :sites, :creator)
              .references(:permissions, :sites, :creator)
              .order(order_clause)

      if is_guest?(user)
        # only anon permissions apply
        query.where('permissions.anonymous_user = TRUE')
      elsif is_admin?(user)
        # admin has access to everything, so if level is none, no projects will be returned.
        level_sym == :none ? Project.none : query
      else

        fail ArgumentError, "User is not valid '#{user}'." unless user.is_a?(User)
        fail ArgumentError, "User id must be an integer, got '#{user.id}'." unless user.id.is_a?(Integer)

        # standard user
        if equal_or_greater_levels.size == 1 && equal_or_greater_levels.include?(:none)
          # get all projects this user cannot access
          # if user has any permissions set or project has logged_in_user not set to null
          # then user does not have :none permission
          # all must be true for this user to have :none access level to the project
          # projects.level cannot be :none

          ids = Project.connection.select_all("SELECT projects.id FROM projects
WHERE
    (NOT EXISTS (SELECT 1 FROM permissions AS per_user WHERE per_user.user_id = #{user.id} AND per_user.project_id = projects.id))
    AND
    (NOT EXISTS (SELECT 1 FROM permissions AS per_logged_in WHERE per_logged_in.logged_in_user = TRUE AND per_logged_in.project_id = projects.id))
ORDER BY #{order_clause}")

          Project.where(id: ids.map { |i| i['id'] })

        else
          # get all projects this user can access
          # if user has permissions set that are equal or higher
          # OR project has logged in permission set to equal or higher
          # then user can access the project

          ids = Project.connection.select_all("SELECT projects.id FROM projects
INNER JOIN permissions on projects.id = permissions.project_id
WHERE
    (permissions.level IN ('#{equal_or_greater_levels.join('\', \'')}') AND permissions.project_id = projects.id AND permissions.user_id = #{user.id})
    OR
    (permissions.level IN ('#{equal_or_greater_levels.join('\', \'')}') AND permissions.project_id = projects.id AND permissions.logged_in_user = TRUE)
ORDER BY #{order_clause}")

          Project.where(id: ids.map { |i| i['id'] })

        end
      end

    end

    # Get all projects this user can access.
    # @param [User] user
    # @return [ActiveRecord::Relation]
    def projects_accessible(user)
      projects(user, :reader)
    end

    # Get all projects this user has no access to.
    # @param [User] user
    # @return [ActiveRecord::Relation]
    def projects_inaccessible(user)
      projects(user, :none)
    end

  end
end