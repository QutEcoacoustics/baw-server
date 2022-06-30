# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# user.password is only available when the password is stored in the model instance.
# loading a user model from the database will not make the password available (as it is hashed)

def ensure_user(user_name:, email:, password:, roles:)
  user = User.where(user_name:).first
  if user.blank?
    user = User.new(user_name:, email:, roles:)
    user.password = password
    user.skip_confirmation!

  else
    user.email = email
    user.password = password unless user.valid_password?(password)
    user.roles = roles
  end
  user.skip_creation_email = true

  user.save!(validate: false)
  user
end

puts 'Loading application seeds...'

# Main admin user must always exist, and must always have these values
admin_user = ensure_user(
  user_name: User::ADMIN_USER_NAME,
  email: Settings.admin_user.email,
  password: Settings.admin_user.password,
  roles: [:admin]
)

# harvester user is for machine access via api, and must always have these values
ensure_user(
  user_name: User::HARVESTER_USER_NAME,
  email: Settings.harvester.email,
  password: Settings.harvester.password,
  roles: [:harvester]
)

# default dataset
default_dataset = Dataset.default_dataset
if default_dataset.blank?
  default_dataset = Dataset.new(name: Dataset::DEFAULT_DATASET_NAME)
  default_dataset.description = 'The default dataset'
  default_dataset.creator_id = admin_user.id
  default_dataset.save!(validate: false)
end

puts 'Finished loading application seeds!'
