class AddTagTextFiltersToDatasets < ActiveRecord::Migration
  def change
    add_column :datasets, :tag_text_filters, :text
  end
end
