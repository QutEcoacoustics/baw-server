class AddAttachmentDatasetResultToDatasets < ActiveRecord::Migration[4.2]
  def change
    add_attachment :datasets, :dataset_result
  end
end
