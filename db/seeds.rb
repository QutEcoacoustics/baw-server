# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#

if User.where(user_name:'Admin').first.blank?
  harvester = User.new(user_name: 'Admin',
                       email: Settings.admin_user.email,
                       password: Settings.admin_user.password)
  harvester.roles = [:admin]
  harvester.skip_confirmation!
  harvester.save!(validate: false)
end

if User.where(user_name:'Harvester').first.blank?
  harvester = User.new(user_name: 'Harvester',
                              email: Settings.harvester.email,
                              password: Settings.harvester.password)
  harvester.roles = [:harvester]
  harvester.skip_confirmation!
  harvester.save!(validate: false)
end

