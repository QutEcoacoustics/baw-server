class AddCategoryToBookmarks < ActiveRecord::Migration[4.2]
  def change
    add_column :bookmarks, :category, :string
  end
end
