class AddDescriptionColumns < ActiveRecord::Migration
  def up
    change_table :sites do |t|
      t.text :description
    end
    change_table :jobs do |t|
      t.text :description
    end
    change_table :bookmarks do |t|
      t.remove :notes
      t.text :description
    end
  end

  def down
    change_table :sites do |t|
      t.remove :description
    end
    change_table :jobs do |t|
      t.remove :description
    end
    change_table :bookmarks do |t|
      t.text :notes
      t.remove :description
    end
  end
end
