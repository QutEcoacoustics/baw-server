class AddDeletedAtAndDeleterIdToUsers < ActiveRecord::Migration
  def change
    # add acts_as_paranoid to users table
    add_column :users, :deleter_id, :integer
    add_column :users, :deleted_at, :datetime
    add_index :users, :deleter_id
  end
end
