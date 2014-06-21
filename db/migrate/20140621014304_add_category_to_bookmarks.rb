class AddCategoryToBookmarks < ActiveRecord::Migration
  def change
    add_column :bookmarks, :category, :string
  end
end
