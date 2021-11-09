# frozen_string_literal: true

class AddOriginalDownloadPermissionToProjects < ActiveRecord::Migration[6.1]
  def change
    change_table(:projects) do |t|
      t.string :allow_original_download, default: nil
    end
  end
end
