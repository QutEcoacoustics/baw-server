class RemoveDefaultsFromUser < ActiveRecord::Migration
  def up
    change_column_default(:users, :email, nil)
    change_column_default(:users, :user_name, nil)
    change_column_default(:users, :encrypted_password, nil)
  end

  def down
    change_table :users do |t|
      t.string :email,              null: false, default: ''
      t.string :user_name,          null: false, default: ''
      t.string :encrypted_password, null: false, default: ''
    end
  end
end
