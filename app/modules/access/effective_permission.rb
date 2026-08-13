# frozen_string_literal: true

module Access
  # Helpers for determining effective permissions inside a query.
  # Useful for list/filtering based on effective permission.
  module EffectivePermission
    TABLE = Arel::Table.new(:effective_permissions).freeze
    TABLE_NAME = TABLE.name.freeze
    LEVEL_NAME = 'level'

    PROJECT_TABLE = Arel::Table.new(:effective_project_permissions).freeze
    PROJECT_TABLE_NAME = PROJECT_TABLE.name.freeze

    module_function

    # Joins the effective permissions CTE to the given query.
    # It must have a project_id column to join on.
    # See #effective_permissions for the description of the query.
    # @param query [ActiveRecord::Relation]
    # @param user [User]
    # @param project_ids [Array<Integer>] filter by project if it is specified
    # @return [ActiveRecord::Relation]
    def add_effective_permissions_cte(query, user, project_ids: nil, project_table: nil)
      project_table ||= Project.arel_table
      cte_query = effective_permissions_for_projects_query(user, project_ids:)

      query
        .with(TABLE_NAME.to_s => cte_query)
        .joins(
          project_table
            .join(TABLE, Arel::Nodes::OuterJoin)
            .on(project_table[:id].eq(TABLE[:project_id]))
            .join_sources
        )
    end

    # Joins effective permissions to a query containing the sites table without changing the query's cardinality.
    # A site can belong to multiple projects, so joining project permissions directly emits one row per project.
    # Instead, retain the performant CTE-and-join design but resolve those project permissions to one row per site.
    # The strongest project permission is exposed as effective_permissions.level for downstream projections.
    # TODO: remove when fixing https://github.com/QutEcoacoustics/baw-server/issues/743
    # @param query [ActiveRecord::Relation] query containing the sites table
    # @param user [User]
    # @param project_ids [Array<Integer>] optional projects through which sites may be accessed
    # @return [ActiveRecord::Relation]
    def add_effective_site_permissions_cte(query, user, project_ids: nil)
      project_permissions = effective_permissions_for_projects_query(user, project_ids:)
      site_permissions = effective_permissions_for_sites_query(project_ids:)
      site_table = Site.arel_table

      query
        .with(
          PROJECT_TABLE_NAME.to_s => project_permissions,
          TABLE_NAME.to_s => site_permissions
        )
        .joins(
          site_table
            .join(TABLE)
            .on(site_table[:id].eq(TABLE[:site_id]))
            .join_sources
        )
    end

    # For the current user, for each project, determine the effective permission level
    # i.e. the highest permission level the user has for that project.
    #
    # Best used as a CTE or subquery. Note should be used with an outer join.
    # If no matching row is found for a project, then the user has no permission for that project.
    #
    # Returns a query with two columns: project_id and level as an integer.
    # (See Access::Permission::LEVEL_TO_INTEGER_MAP for mapping of permission levels to integers.)
    # @param user [User]
    # @param project_ids [Array<Integer>] filter by project if it is specified
    # @return [Arel::SelectManager] Arel query that returns project_id and level
    def effective_permissions_for_projects_query(user, project_ids: nil)
      user = Access::Validate.user(user)

      p = Project.arel_table
      pm = ::Permission.arel_table

      if Access::Core.is_admin?(user)
        owner_level = Permission::LEVEL_TO_INTEGER_MAP[Permission::OWNER]
        # weirdness alert: basically just returns all project_ids from the projects table
        # rather than from the permissions table.
        # We do this because we want one row per project, even if the admin user has no
        # explicit permissions set.
        return p
            # optimization to reduce number of rows processed
            .if_then(project_ids.present?) { _1.where(p[:id].in(project_ids)) }
            .project(
              p[:id].as('project_id'),
              Arel.sql(owner_level.to_s).as(LEVEL_NAME)
            )
      end

      case_statement = pm[:level]
        .when(Permission::OWNER).then(Permission::LEVEL_TO_INTEGER_MAP[Permission::OWNER])
        .when(Permission::WRITER).then(Permission::LEVEL_TO_INTEGER_MAP[Permission::WRITER])
        .when(Permission::READER).then(Permission::LEVEL_TO_INTEGER_MAP[Permission::READER])
        # I don't think this case can happen, since we don't store 'none', but just in case...
        .else(Permission::LEVEL_TO_INTEGER_MAP[Permission::NONE])

      query = pm

      # This is mainly an optimization to reduce the number of rows we need to process.
      # The parent query will still have to join to get the project ids we want.
      query = pm.where(pm[:project_id].in(project_ids)) if project_ids.present?

      # if we have a user, then filter for user or logged in permissions
      if user.present?
        query.where(pm[:user_id].eq(user.id).or(pm[:allow_logged_in].eq(true)))
      else
        # or we have no user, so filter out all irrelevant user or logged_in permissions
        query.where(pm[:allow_anonymous].eq(true))
      end => query

      query
        .group(pm[:project_id])
        .project(
          pm[:project_id],
          case_statement.maximum.as(LEVEL_NAME)
        )
    end

    # Resolves project permissions to one effective permission row per site.
    # MAX is intentional: access through any associated project grants the strongest available level, while the
    # left join and COALESCE retain sites whose associated projects grant no permission. Returning exactly one row
    # per site prevents projects_sites fan-out from duplicating sites and every record derived from them.
    # @param project_ids [Array<Integer>] optional projects through which sites may be accessed
    # @return [Arel::SelectManager] query returning site_id and level
    def effective_permissions_for_sites_query(project_ids: nil)
      projects_sites = ProjectsSite.arel_table
      level = Arel.coalesce(PROJECT_TABLE[LEVEL_NAME], Permission.none_value).maximum.as(LEVEL_NAME)

      query = projects_sites
        .join(PROJECT_TABLE, Arel::Nodes::OuterJoin)
        .on(projects_sites[:project_id].eq(PROJECT_TABLE[:project_id]))
        .group(projects_sites[:site_id])
        .project(projects_sites[:site_id], level)

      query = query.where(projects_sites[:project_id].in(project_ids)) if project_ids.present?

      query
    end

    # Builds an Arel predicate for filtering by effective permission level.
    # Returns any record that is greater than or equal to the given level.
    # @param level [Symbol] permission level (see Permission levels)
    # @return [Arel::Nodes::Node] Arel predicate
    def build_minimum_level_predicate(level)
      level = Access::Validate.level(level)

      Arel
        .coalesce(TABLE[LEVEL_NAME], Permission.none_value)
        .gteq(Permission.level_to_value(level))
    end

    # Builds an Arel predicate for filtering by effective permission level.
    # Returns any record that is less than (and not equal to) the given level.
    # This is useful for filtering out records that the user has too much access to.
    # @param level [Symbol] permission level (see Permission levels)
    # @return [Arel::Nodes::Node] Arel predicate
    def build_maximum_level_predicate(level)
      level = Access::Validate.level(level)

      Arel
        .coalesce(TABLE[LEVEL_NAME], Permission.none_value)
        .lt(Permission.level_to_value(level))
    end

    # Builds an Arel predicate for filtering by effective permission levels.
    # Returns any record that matches one of the given levels.
    # @param levels [Array<Symbol>] permission levels (see Permission levels)
    # @return [Arel::Nodes::Node] Arel predicate
    def build_levels_predicate(levels)
      levels = Access::Validate.levels(levels)

      level_values = Permission.levels_to_values(levels)

      Arel
        .coalesce(TABLE[LEVEL_NAME], Permission.none_value)
        .in(level_values)
    end
  end
end
