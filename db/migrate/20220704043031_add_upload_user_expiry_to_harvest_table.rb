# frozen_string_literal: true

# Track the upload user's expiry date
class AddUploadUserExpiryToHarvestTable < ActiveRecord::Migration[7.0]
  def change
    change_table :harvests do |t|
      t.datetime :upload_user_expiry_at
    end
  end
end
