class UserNameUnique < ActiveRecord::Migration
  def change
    add_index  :users, :user_name, name: 'users_user_name_unique', unique: true
  end
end
