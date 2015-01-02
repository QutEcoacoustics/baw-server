class ModifyPermission < ActiveRecord::Migration

  def up
    add_column :permissions, :logged_in_user, :boolean, default: false, null: false
    add_column :permissions, :anonymous_user, :boolean, default: false, null: false

    change_column :permissions, :user_id, :integer, default: nil, null: true

    remove_column :projects, :anonymous_level
    remove_column :projects, :sign_in_level

    admin = User.where(user_name: 'Admin').first

    # generate owner entries from project.creator_id
    # the records are created by admin
    Project.all.each do |project|

      existing_permissions = Permission.where(project_id: project.id, user_id: project.creator_id)
      existing_permissions_count = existing_permissions.count

      fail RuntimeError, "More than one permission! #{existing_permissions.all.to_json}" if existing_permissions_count > 1

      if existing_permissions_count == 0
        permission = Permission.new(level: 'owner', project_id: project.id, user_id: project.creator_id)

        permission.creator = admin
        permission.updater = admin

        permission.save!
        puts "Permission created #{permission.to_json}."
      else
        existing_permission = existing_permissions.first

        existing_permission.level = 'owner'
        existing_permission.updater = admin

        existing_permission.save!
        puts "Permission updated #{existing_permission.to_json}."
      end

    end
  end

  def down
    remove_column :permissions, :logged_in_user
    remove_column :permissions, :anonymous_user

    add_column :projects, :anonymous_level, :string, default: 'none', null: false
    add_column :projects, :sign_in_level, :string, default: 'none', null: false

    # remove owner Permissions - ownership is specified by project.creator_id
    Permission.where(level: 'owner').destroy_all
  end

end
