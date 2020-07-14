class AddTagTextFiltersToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_column :datasets, :tag_text_filters, :text
  end
end
