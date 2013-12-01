class AddAttachmentDatasetResultToDatasets < ActiveRecord::Migration
  def change
    add_attachment :datasets, :dataset_result
  end
end
