module Access
  class Model
    class << self

      # Get projects for which this user has these access levels.
      # @param [User] user
      # @param [Symbol, Array<Symbol>] levels
      # @return [ActiveRecord::Relation] projects
      def projects(user, levels)
        user = Access::Core.validate_user(user)
        levels = Access::Core.validate_levels(levels)

=begin
SELECT projects.*
  FROM projects
WHERE
--NOT
EXISTS
        (SELECT 1
        FROM "permissions"
        WHERE
            "permissions"."level" IN ('reader', 'writer', 'owner')
            AND "projects"."id" = "permissions"."project_id"

            AND (
            --"permissions"."user_id" = 138
            --OR
            "permissions"."allow_anonymous" = TRUE OR "permissions"."allow_logged_in" = TRUE
            )
        )
=end

        query = Project.order('lower(projects.name) ASC')
        Access::Apply.restrictions(user, levels, query)
      end

    end
  end
end