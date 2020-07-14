class UserNameUnique < ActiveRecord::Migration[4.2]
  def change
    add_index  :users, :user_name, name: 'users_user_name_unique', unique: true
  end
end
