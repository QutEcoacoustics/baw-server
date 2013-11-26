class AddRolesMaskToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :roles_mask, :integer

    # harvester user is created in seeds.rb
    user = User.create( :email => 'admin@example.com', :user_name => 'admin', :password => 'password' )
    user.roles = [:admin]
    user.skip_confirmation!
    user.save!
  end
  def self.down
    remove_column :users, :roles_mask
  end
end
