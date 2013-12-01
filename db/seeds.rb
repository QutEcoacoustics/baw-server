# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#

if User.find_by_user_name('Admin').blank?
  harvester = User.new(user_name: 'Admin',
                       email: Settings.admin_user.email,
                       password: Settings.admin_user.password)
  harvester.roles = [:admin]
  harvester.skip_confirmation!
  harvester.save!
end

if User.find_by_user_name('Harvester').blank?
  harvester = User.new(user_name: 'Harvester',
                              email: Settings.harvester.email,
                              password: Settings.harvester.password)
  harvester.roles = [:harvester]
  harvester.skip_confirmation!
  harvester.save!
end

