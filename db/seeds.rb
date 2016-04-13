# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#

if User.where(user_name: 'Admin').first.blank?
  admin = User.new
else
  admin = User.where(user_name: 'Admin').first
end
admin.user_name = 'Admin'
admin.email = Settings.admin_user.email
admin.password = Settings.admin_user.password
admin.roles = [:admin]
admin.skip_confirmation!
admin.save!(validate: false)


if User.where(user_name: 'Harvester').first.blank?
  harvester = User.new
else
  harvester = User.where(user_name: 'Harvester').first
end

harvester.user_name = 'Harvester'
harvester.email = Settings.harvester.email
harvester.password = Settings.harvester.password
harvester.roles = [:harvester]
harvester.skip_confirmation!
harvester.save!(validate: false)


