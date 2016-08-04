class EnableAnonymousAccess < ActiveRecord::Migration
  def up
    add_column :permissions, :allow_logged_in, :boolean, default: false, null: false
    add_column :permissions, :allow_anonymous, :boolean, default: false, null: false

    change_column :permissions, :user_id, :integer, default: nil, null: true

    # old indexes are not applicable
    remove_index :permissions, column: [:project_id, :user_id]
    remove_index :permissions, name: 'permissions_level_user_id_project_id_uidx'

    # ensure the three permission types are exclusive
    execute 'ALTER TABLE permissions
ADD CONSTRAINT permissions_exclusive_cols
CHECK ((user_id IS NOT NULL AND NOT allow_logged_in AND NOT allow_anonymous)
    OR (user_id IS NULL AND allow_logged_in AND NOT allow_anonymous)
    OR (user_id IS NULL AND NOT allow_logged_in AND allow_anonymous))'

    # ensure each project has only one record for each user
    add_index  :permissions, [:project_id, :user_id], unique: true, where: 'user_id IS NOT NULL', name: 'permissions_project_user_uidx'

    # ensure each project has only one record that is allow_logged_in: true
    add_index  :permissions, [:project_id, :allow_logged_in], unique: true, where: 'allow_logged_in IS TRUE', name: 'permissions_project_allow_logged_in_uidx'

    # ensure each project has only one record that is allow_anonymous: true
    add_index :permissions, [:project_id, :allow_anonymous], unique: true, where: 'allow_anonymous IS TRUE', name: 'permissions_project_allow_anonymous_uidx'

    # Admin will have been created by seeds.rb
    admin = User.where(user_name: 'Admin').first

    # generate owner entries from project.creator_id
    # the records are created by admin
    Project.all.each do |project|

      existing_permissions = Permission.where(project_id: project.id, user_id: project.creator_id)
      existing_permissions_count = existing_permissions.count

      if existing_permissions_count == 0
        permission = Permission.new(level: 'owner', project_id: project.id, user_id: project.creator_id)

        permission.creator = admin
        permission.updater = admin

        permission.save!
        puts "Permission created #{permission.to_json}."
      elsif existing_permissions_count == 1
        existing_permission = existing_permissions.first

        existing_permission.level = 'owner'
        existing_permission.updater = admin

        existing_permission.save!
        puts "Permission updated #{existing_permission.to_json}."
      else
        fail RuntimeError, "Expecting 0 or 1 permission for one user and project, got #{existing_permissions_count}: #{existing_permissions.all.to_json}"
      end

    end
  end

  def down
    # Undo changes in reverse order.

    # remove owner Permissions - ownership is specified by project.creator_id
    Permission.where(level: 'owner').destroy_all

    remove_index :permissions, name: 'permissions_project_allow_anonymous_uidx'
    remove_index :permissions, name: 'permissions_project_allow_logged_in_uidx'
    remove_index :permissions, name: 'permissions_project_user_uidx'

    execute 'ALTER TABLE permissions DROP CONSTRAINT permissions_exclusive_cols'

    add_index  :permissions, [:project_id, :level, :user_id], name: 'permissions_level_user_id_project_id_uidx', unique: true,
               order: {project_id: :asc, user_id: :asc}
    add_index :permissions, [:project_id, :user_id]

    change_column :permissions, :user_id, :integer, null: false

    remove_column :permissions, :allow_logged_in
    remove_column :permissions, :allow_anonymous
  end
end
