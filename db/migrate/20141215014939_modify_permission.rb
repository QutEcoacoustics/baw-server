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
      permission = Permission.new(level: 'owner', project_id: project.id, user_id: project.creator_id)
      exists = Permission.where(level: 'owner', project_id: project.id, user_id: project.creator_id).exists?

      if exists
        puts "Permission already exists #{permission.to_json}."
      else
        permission.creator = admin
        permission.updater = admin
        permission.save!
        puts "Permission created #{permission.to_json}."
      end

    end
  end

  def down
    remove_column :permissions, :logged_in_user
    remove_column :permissions, :anonymous_user

    add_column :projects, :anonymous_level, :string, default: 'none', null: false
    add_column :projects, :sign_in_level, :string, default: 'none', null: false
  end

end
