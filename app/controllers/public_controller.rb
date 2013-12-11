class PublicController < ApplicationController
  def index
    base_path = "#{Rails.root}/public"
    image_base = '/system/home/'
    json_data_file = base_path+image_base+'animals.json'
    sensor_tree = base_path+image_base+'sensor_tree.jpg'
    if File.exists?(json_data_file) && File.exists?(sensor_tree)
      species_data = JSON.load(File.read json_data_file)
      item_count = species_data['species'].size
      item_index = rand(item_count)
      # select a random image with audio and sensor tree
      @selected_images = {animal: species_data['species'][item_index], sensor_tree: "#{image_base}sensor_tree.jpg", image_base: image_base+'media/'}
    end

    respond_to do |format|
      format.html
      format.json { no_content_as_json }
    end
  end
end