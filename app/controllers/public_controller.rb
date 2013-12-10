class PublicController < ApplicationController
  def index
    base_path = "#{Rails.root}/public"
    image_base = '/system/home/'
    json_data_file = base_path+image_base+'data.js'
    sensor_tree = base_path+image_base+'sensor_tree.jpg'
    if File.exists?(json_data_file) && File.exists?(sensor_tree)
      species_data = JSON.load(File.read json_data_file)
      item_index = rand(species_data['data'].size)
      # select a random image with audio and sensor tree
      @selected_images = {animal: species_data['data'][item_index], sensor_tree: 'sensor_tree.jpg', image_base: image_base}
    end

    respond_to do |format|
      format.html
      format.json { no_content_as_json }
    end
  end
end