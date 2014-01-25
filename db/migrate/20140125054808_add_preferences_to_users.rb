class AddPreferencesToUsers < ActiveRecord::Migration
  def change
    add_column :users, :preferences, :text
  end
end
