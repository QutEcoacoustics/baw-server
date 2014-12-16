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
              description: 'created the project or is assigned as owner'
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

    # Convert an access level to a symbol and check it is valid.
    # @param [Object] value
    # @return [Symbol]
    def obj_to_sym(value)
      validate(value)
    end

    # Convert an access level to a string and check it is valid.
    # @param [Object] value
    # @return [String]
    def obj_to_str(value)
      value_sym = validate(value)
      value_sym.to_s
    end

    # Convert an access level to its display value.
    # @param [Object] value
    # @return [String]
    def obj_to_display(value)
      value_sym = validate(value)
      values[value_sym][:display]
    end

    # Convert an access level to its description.
    # @param [Object] value
    # @return [String]
    def obj_to_description(value)
      value_sym = validate(value)
      values[value_sym][:description]
    end

    # check if requested access level is allowed based on actual access level.
    # @param [Symbol] requested
    # @param [Symbol] actual
    # @return [Boolean]
    def check(requested, actual)
      access_levels = decompose(actual)
      requested_sym = validate(requested)
      access_levels.include?(requested_sym)
    end

    # Validate array of access levels.
    # @param [Array<Symbol>] value
    # @return [void]
    def validate_array(value)
      if value.respond_to?(:each)
        value.each { |i| validate(i) }
      else
        fail ArgumentError, "Value must be a collection of items, got #{value.class}."
      end
    end

    # Validate access level.
    # @param [Object] value
    # @return [void]
    def validate(value)
      fail ArgumentError, 'Access level must not be blank.' if value.blank?
      valid = values.keys
      value_sym = value.to_sym
      fail ArgumentError, "Access level '#{value}' is not in available levels '#{valid}'." unless valid.include?(value_sym)

      value_sym
    end

    # Get an array of access levels for this access level.
    # @param [Symbol] actual
    # @return [Array<Symbol>]
    def decompose(actual)
      actual_sym = obj_to_sym(actual)
      case actual_sym
        when :owner
          [:reader, :writer, :owner]
        when :writer
          [:reader, :writer]
        when :reader
          [:reader]
        when :none
          [:none]
        else
          fail ArgumentError, "Can not decompose #{actual}, must be one of #{values.keys.join(', ')}."
      end

    end

    # Get an array of access levels that are equal or greater.
    # @param [Symbol] actual
    # @return [Array<Symbol>]
    def equal_or_greater(actual)
      actual_sym = obj_to_sym(actual)
      case actual_sym
        when :owner
          [:owner]
        when :writer
          [:writer, :owner]
        when :reader
          [:reader, :writer, :owner]
        when :none
          [:none]
        else
          fail ArgumentError, "Can not get equal or greater for #{actual}, must be one of #{values.keys.join(', ')}."
      end
    end

    # Get the highest access level.
    # @param [Array<Symbol>] levels
    # @return [Symbol]
    def highest(levels)
      validate_array(levels)

      # set to lowest to begin
      highest = :none
      levels.each do |level|
        # owner is the highest possible level
        return :owner if level == :owner
        # writer is higher than none and reader
        highest = level if level == :writer && [:none, :reader].include?(highest)
        # reader is higher than none
        highest = level if level == :reader && :none == highest
      end
      highest
    end

    # Get the lowest access level.
    # @param [Array<Symbol>] levels
    # @return [Symbol]
    def lowest(levels)
      validate_array(levels)

      # set to highest to begin
      lowest = :owner
      levels.each do |level|
        # none is the lowest level
        return :none if level == :none
        # reader is lower than owner and writer
        lowest = level if level == :reader && [:owner, :writer].include?(lowest)
        # writer is lower than owner
        lowest = level if level == :writer && :owner == lowest
      end
      lowest
    end


    # =====================================
    # Basic access level methods
    # (do not take higher levels into account when getting access level)
    # =====================================

    # TODO: needs to separate out different permissions

    #
    def permissions(project, user = nil)
      fail ArgumentError, 'Project must be provided.' if project.blank?

      if user.nil?
        permissions = Permission.where(project_id: project.id)
      else
        permissions = Permission.where(project_id: project.id, user_id: user.id)
      end
      permissions
    end

    # permissions can come from a Permission, project.signed_in_level,
    # project.anonymous_level, user/admin, creator

    # Assumes that a guest user will be nil or not confirmed.

    # Does this user have the specified access level via permission on this project?
    # @param [User] user
    # @param [Project] project
    # @param [Object] level
    # @return [Boolean]
    def permission_level?(user, project, level)
      level_requested = validate(level)
      level_actual = permission_level(user, project)

      check(level_requested, level_actual)
    end

    # Get Permission access level for this user and project.
    # @param [User] user
    # @param [Project] project
    # @return [Symbol]
    def permission_level(user, project)
      fail ArgumentError, 'Project must be provided.' if project.blank?
      return :none if is_guest?(user)

      first_item = Permission.where(user_id: user.id, project_id: project.id).first
      first_item.blank? ? :none : obj_to_sym(first_item.level)
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
      user.blank? || !user.confirmed?
    end

    # =====================================
    # Advanced access level methods
    # (do take higher levels into account when getting access level:
    # if a user can write a project, they can also read, even if read access is not explicitly allowed)
    # =====================================

    # Does this user have this access to this project?
    # @param [User] user
    # @param [Project] project
    # @param [Symbol] level
    # @return [Boolean]
    def access?(user, project, level)
      fail ArgumentError, 'Project must be provided.' if project.blank?
      validate(level)

      if is_guest?(user)
        # only anon permissions apply
        check(level, anonymous_level(project))
      elsif is_admin?(user)
        # admin always has access
        true
      else
        # standard user
        # being the creator of a project gives :owner access level,
        # so if is_creator? is true, then result will be true
        # except when checking :none access level.
        if level == :none
          # must all be none, otherwise it is not none (it is reader, writer, or owner)
          # e.g. asking for :none, sign_in_level is :reader, permission_level is :none, is_creator? is false (=> false)
          sign_in_check = check(level, sign_in_level(project))
          permission_check = check(level, permission_level(user, project))
          creator_check = is_creator?(user, project)

          sign_in_check && permission_check && !creator_check
        else # :reader, :writer, :owner
          # any can be true - some might be false (lower levels)
          # e.g. asking for :writer, sign_in_level is :reader, permission_level is :writer, is_creator? is false (=> true)

          sign_in_check = check(level, sign_in_level(project))
          permission_check = check(level, permission_level(user, project))
          creator_check = is_creator?(user, project)

          sign_in_check || permission_check || creator_check
        end
      end
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


    # =====================================
    # Project(s) / access level(s)
    # =====================================

    def sql_fragment_sign_in(access_levels)
      access_levels_check = access_levels.map { |item| "'#{item}'" }.join(', ')
      "projects.sign_in_level IN (#{access_levels_check})"
    end

    def sql_fragment_permissions_check(access_levels)
      access_levels_check = access_levels.map { |item| "'#{item}'" }.join(', ')
      "(permissions.user_id = ? AND permissions.level IN (#{access_levels_check}))"
    end

    # being the creator of a project gives :owner access level
    def sql_fragment_creator_id_check
      'projects.creator_id = ?'
    end

    def sql_fragment_permissions_exist
      'SELECT 1 FROM permissions AS per_check WHERE per_check.user_id = ?'
    end

    def sql_fragment_creator_id_exist
      'SELECT 1 FROM projects AS p_check WHERE p_check.creator_id = ?'
    end

    # All projects that this user has at least this access level for.
    # @param [User] user
    # @param [Symbol] level
    # @return [ActiveRecord::Relation]
    def projects(user, level)
      validate(level)

      at_least_levels = equal_or_greater(level)

      query =
          Project
              .includes(:permissions, :sites, :creator)
              .references(:permissions, :sites, :creator)
              .order('lower(projects.name) DESC')

      if is_guest?(user)
        # only anon permissions apply
        query.where(anonymous_level: at_least_levels)

      elsif is_admin?(user)
        # admin has access to everything
        query

      else

        # permissions.level can be :reader, :writer, or :owner
        # sign_in_level can be :none, :reader, :writer, or :owner
        # @see Permission
        sign_in_check = sql_fragment_sign_in(at_least_levels)

        # standard user
        if at_least_levels.size == 1 && at_least_levels.include?(:none)
          # get projects this user cannot access
          # if user is creator or user has any permissions set
          # then user does not have :none permission
          # all must be true for this user to have :none access level to the project
          where_clause = "(NOT EXISTS (#{sql_fragment_creator_id_exist}) AND NOT EXISTS (#{sql_fragment_permissions_exist}) AND #{sign_in_check})"
          query.where(where_clause, user.id, user.id)

        else
          # projects this user can access at the given access levels
          permissions_check = sql_fragment_permissions_check(at_least_levels)

          # any one of these being true will allow the specified access level to the project
          where_clause = "(#{sql_fragment_creator_id_check} OR #{permissions_check} OR #{sign_in_check})"
          query.where(where_clause, user.id, user.id)
        end
      end
    end

    def accessible_projects(user)
      projects(user, :reader)
    end

    def inaccessible_projects(user)
      projects(user, :none)
    end

    # Get the highest access level this user has for this project.
    # @param [User] user
    # @param [Project] project
    # @return [Symbol]
    def level(user, project)
      if is_guest?(user)
        anonymous_level(project)
      elsif is_admin?(user)
        :owner
      else
        return :owner if is_creator?(user, project)

        # return the highest of sign_in_level and permission_level
        sign_in_access_level = sign_in_level(project)
        permission_access_level = permission_level(user, project)

        highest(
            [
                sign_in_access_level,
                permission_access_level
            ])
      end
    end
  end
end