module Access
  # This is a mirror for Access::ByPermission that uses the Effective Permission common table expression (CTE).
  # It's different in two ways:
  #   1. It uses a more modern approach that calculates permissions in a separate CTE
  #      and joins that to the main query, rather than joining the permissions table multiple time
  #      in per-row subqueries.
  #   2. It exposes the effective permission level query so that it can be used in complex queries.
  #      e.g. The driving use case is customizing data which should be visible to everyone, but
  #      obfuscated for users without sufficient permission.
  #
  # Any methods in here should have a corresponding method in Access::ByPermission and should have tests
  # asserting their behaviour is identical.
  module ByPermissionTable
    extend EffectivePermission

    module_function

    # Returns a query for projects the user has at least the given level of permission for.
    # @param user [User]
    # @param level [Symbol] the minimum permission level (see Permission levels)
    # @param levels [Array<Symbol>] alternative to level, an array of specific permission levels (see Permission levels)
    # @return [ActiveRecord::Relation<Project>] the approved projects
    def projects(user, level: nil, levels: nil)
      query = Project.all

      apply(user, query, level:, levels:)
    end

    # Returns a query for sites the user has at least the given level of permission for.
    # @param user [User]
    # @param level [Symbol] the minimum permission level (see Permission levels)
    # @param levels [Array<Symbol>] alternative to level, an array of specific permission levels (see Permission levels)
    # @param project_ids [Array<Integer>] optional list of project IDs to further restrict results
    # @return [ActiveRecord::Relation<Site>] the approved sites
    def sites(user, level: nil, levels: nil, project_ids: nil)
      query = Site.joins(:projects)

      apply(user, query, level:, levels:, project_ids:)
    end

    def apply(user, query, level:, levels: nil, project_ids: nil)
      user = Access::Validate.user(user)
      validate_levels(level, levels)

      if levels.present?
        # special case: if levels is effectively NONE, and the user is Admin, then return nothing
        # because admin has access to everything, so asking for things it doesn't have access to breaks our query logic
        return query.none if Access::Core.is_admin?(user) && Access::Core.is_no_level?(levels)

        build_levels_predicate(levels)
      else
        build_minimum_level_predicate(level)
      end => predicate

      predicate = predicate.and(Project.arel_table[:id].in(project_ids)) if project_ids.present?

      add_effective_permissions_cte(query, user, project_ids:).where(predicate)
    end

    def validate_levels(level, levels)
      raise ArgumentError, 'Cannot specify both level and levels.' if levels.present? && level.present?
      raise ArgumentError, 'Must specify either level or levels.' if levels.blank? && level.blank?
    end

    private_class_method :apply, :validate_levels
  end
end
