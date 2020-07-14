class AddImageColumnsToUser < ActiveRecord::Migration[4.2]
  def change
    add_attachment :users, :image
  end
end
