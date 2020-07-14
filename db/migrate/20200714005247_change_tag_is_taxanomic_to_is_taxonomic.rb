class ChangeTagIsTaxanomicToIsTaxonomic < ActiveRecord::Migration[6.0]
  def change
    change_table :tags do |t|
      t.rename :is_taxanomic, :is_taxonomic
    end
  end
end
