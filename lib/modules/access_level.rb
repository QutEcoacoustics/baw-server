class AccessLevel

  # =====================================
  # access level hash
  # =====================================

  # Get a hash with display and description for the available access levels.
  # @return [Hash]
  def self.values
    {
        owner: {
            display: 'Owner',
            description: ''
        },
        writer: {
            display: 'Writer',
            description: ''
        },
        reader: {
            display: 'Reader',
            description: ''
        },
        none: {
            display: 'None',
            description: ''
        }
    }
  end

  # Convert an access level to a symbol and check it is valid.
  # @param [Object] value
  # @return [Symbol]
  def self.obj_to_sym(value)
    valid = values.keys
    value_sym = value.to_sym
    fail ArgumentError, "Access level #{value} is not in available levels #{valid}." unless valid.include?(value_sym)

    value_sym
  end

  # Convert an access level to a string and check it is valid.
  # @param [Object] value
  # @return [String]
  def self.obj_to_str(value)
    valid = values.keys
    value_sym = value.to_sym
    fail ArgumentError, "Access level #{value} is not in available levels #{valid}." unless valid.include?(value_sym)

    value_sym.to_s
  end

  # check if requested access level is allowed based on actual access level.
  # @param [Symbol] requested
  # @param [Symbol] actual
  # @return [Boolean]
  def self.check(requested, actual)
    access_levels = decompose(actual)
    requested_sym = obj_to_sym(requested)
    access_levels.include?(requested_sym)
  end

  # Get an array of access levels for this access level.
  # @param [Symbol] actual
  # @return [Array<Symbol>]
  def self.decompose(actual)

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
        [:none]
    end

  end

  # Get the highest access level.
  # @param [Array<Symbol>] levels
  # @return [Symbol]
  def self.highest(levels)
    highest = :none
    levels.each do |level|
      return :owner if level == :owner
      highest = level if level == :writer && [:none, :reader].include?(highest)
      highest = level if level == :reader && :none == highest
    end
    highest
  end

  # Get the lowest access level.
  # @param [Array<Symbol>] levels
  # @return [Symbol]
  def self.lowest(levels)
    lowest = :owner
    levels.each do |level|
      return :none if level == :none
      lowest = level if level == :reader && [:owner, :writer].include?(lowest)
      lowest = level if level == :writer && :owner == lowest
    end
    lowest
  end

  # =====================================
  # Basic access level methods
  # (do not take higher levels into account when getting access level)
  # =====================================

  # permissions can come from a Permission, project.signed_in_level,
  # project.anonymous_level, user.roles/user.has_role?

  # Assumes that a guest user will be nil or not confirmed.

  # Does this user have the specified access level via permission on this project?
  # @param [User] user
  # @param [Project] project
  # @param [Object] level
  # @return [Boolean]
  def permission_level?(user, project, level)
    return false if is_guest?(user)
    has_permission = Permission.where(user_id: user.id, project_id: project.id, level: AccessLevel.obj_to_str(level)).exists?
    if level == :none && has_permission
      false
    elsif level == :none && !has_permission
      true
    else
      has_permission
    end
  end

  # Get Permission access level for this user and project.
  # @param [User] user
  # @param [Project] project
  # @return [Symbol]
  def permission_level(user, project)
    return :none if is_guest?(user)
    first_item = Permission.where(user_id: user.id, project_id: project.id).first
    first_item.blank? ? :none : AccessLevel.obj_to_sym(first_item.level)
  end

  # Get the signed in access level for this project.
  # @param [Project] project
  # @return [Symbol]
  def sign_in_level(project)
    AccessLevel.obj_to_sym(project.sign_in_level)
  end

  # Get the anonymous access level for this project.
  # @param [Project] project
  # @return [Symbol]
  def anonymous_level(project)
    AccessLevel.obj_to_sym(project.anonymous_level)
  end

  # Is this user the creator of project?
  # @param [User] user
  # @param [Project] project
  # @return [Boolean]
  def is_creator?(user, project)
    return false if is_guest?(user)
    project.creator == user
  end

  # Is this user the updater of project?
  # @param [User] user
  # @param [Project] project
  # @return [Boolean]
  def is_updater?(user, project)
    return false if is_guest?(user)
    project.updater == user
  end

  # Is this user the deleter of project?
  # @param [User] user
  # @param [Project] project
  # @return [Boolean]
  def is_deleter?(user, project)
    return false if is_guest?(user)
    project.deleter == user
  end

  # Is this user an owner of this project?
  # @param [User] user
  # @param [Project] project
  # @return [Boolean]
  def is_owner?(user, project)
    return false if is_guest?(user)
    permission_level?(user, project, :owner)
  end

  # Is this user an admin?
  # @param [User] user
  # @return [Boolean]
  def is_admin?(user)
    return false if is_guest?(user)
    user.has_role?(:admin)
  end

  # Is this user a guest? (a guest = nil user object)
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
    if is_guest?(user)
      # only anon permissions apply
      AccessLevel.check(level, anonymous_level(project))
    elsif is_admin?(user)
      # admin always has access
      true
    else
      # standard user
      # being the creator of a project gives :owner access level
      if level == :none
        # must all be none, otherwise it is not none (it is reader, writer, or owner)
        # e.g. asking for :none, sign_in_level is :reader, permission_level is :none, is_creator? is false (=> false)
        AccessLevel.check(level, sign_in_level(project)) &&
            AccessLevel.check(level, permission_level(user, project)) &&
            !is_creator?(user, project)
      else
        # any can be true - some might be false (lower levels)
        # e.g. asking for :writer, sign_in_level is :reader, permission_level is :writer, is_creator? is false (=> true)
        AccessLevel.check(level, sign_in_level(project)) ||
            AccessLevel.check(level, permission_level(user, project)) ||
            is_creator?(user, project)
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


  # All projects this user has this access level for.
  # @param [User] user
  # @param [Symbol] level
  # @return [ActiveRecord::Relation]
  def projects(user, level)

    access_levels = AccessLevel.decompose(level)

    if is_guest?(user)
      # only anon permissions apply
      Project
      .includes(:permissions, :sites, :creator)
      .where(anonymous_level: access_levels)
      .order('projects.name DESC')

    elsif is_admin?(user)
      # admin has access to everything
      Project.scoped

    else
      # standard user
      if access_levels.size == 1 && access_levels[0] == :none
        # get projects this user cannot access

        # TODO

      else
        # projects this user can access that the given levels
        projects = Project
        .includes(:permissions, :sites, :creator)
        .order('projects.name DESC')

        # use access_levels in permissions check
        access_levels_check = access_levels.map { |item| "'#{item}'" }.join(', ')
        permissions_check = "(permissions.user_id = ? AND permissions.level IN (#{access_levels_check}))"
        sign_in_check = "projects.sign_in_level IN (#{access_levels_check})"

        if access_levels.include?(:owner)
          # being the creator of a project gives :owner access level
          creator_id_check = 'projects.creator_id = ?'
          where_clause = "(#{creator_id_check} OR #{permissions_check} OR #{sign_in_check})"
          projects.where(where_clause, user.id, user.id)
        else

          where_clause = "(#{permissions_check} OR #{sign_in_check})"
          projects.where(where_clause, user.id)
        end

      end
    end

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

      AccessLevel.highest(
          [
              sign_in_access_level,
              permission_access_level
          ])
    end
  end

end