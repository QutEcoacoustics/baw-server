class AddRolesMaskToUsers < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :roles_mask, :integer
  end
  def self.down
    remove_column :users, :roles_mask
  end
end
