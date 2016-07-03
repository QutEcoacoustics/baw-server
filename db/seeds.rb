# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# user.password is only available when the password is stored in the model instance.
# loading a user model from the database will not make the password available (as it is hashed)

# Main admin user must always exist
admin_user = User.where(user_name: 'Admin').first

if admin_user.blank?
  admin_user = User.new(user_name: 'Admin')
  admin_user.email = Settings.admin_user.email
  admin_user.password = Settings.admin_user.password
  admin_user.roles = [:admin]
  admin_user.skip_confirmation!
  admin_user.save!(validate: false)
end


# harvester user is for machine access via api
harvester_user = User.where(user_name: 'Harvester').first
if harvester_user.blank?
  harvester_user = User.new(user_name: 'Harvester')
  harvester_user.email = Settings.harvester.email
  harvester_user.password = Settings.harvester.password
  harvester_user.roles = [:harvester]
  harvester_user.skip_confirmation!
  harvester_user.save!(validate: false)
end

