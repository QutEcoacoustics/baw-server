class AddTimeZoneNameToUser < ActiveRecord::Migration
  def change
    add_column :users, :time_zone_name, :string, null:false, default: 'Brisbane'
  end
end
