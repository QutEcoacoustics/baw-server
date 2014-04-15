class PublicController < ApplicationController

  skip_authorization_check only: [:index, :status, :website_status]

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
      @selected_images = {
          animal: species_data['species'][item_index],
          sensor_tree: "#{image_base}sensor_tree.jpg",
          image_base: image_base+'media/',
          example_spectrogram: "#{image_base}spectrogram_example.jpg",
          ecologist: "#{image_base}eco.jpg",
      }
    end

    respond_to do |format|
      format.html
      format.json { no_content_as_json }
    end
  end

  def status
    # only returns json
    # for now only indicates if audio recording storage is available
    storage_msg = AudioRecording.check_storage
    status = storage_msg[:success] ? 'good' : 'bad'
    respond_to do |format|
      format.json { render json: {status: status, storage: storage_msg}, status: :ok }
    end
  end

  def website_status

    storage_msg = AudioRecording.check_storage

    online_window = 2.hours.ago
    users_online = User.where('current_sign_in_at > ? OR last_sign_in_at > ?', online_window, online_window).count
    users_total = User.count

    month_ago = 1.month.ago
    annotations_total = AudioEvent.count
    annotations_recent = AudioEvent.where('created_at > ? OR updated_at > ?', month_ago, month_ago).count
    #annotations_total_duration = BigDecimal.new(AudioEvent.sum('end_time_seconds - start_time_seconds'))

    audio_recording_total = AudioRecording.count
    audio_recording_recent = AudioRecording.where('created_at > ? OR updated_at > ?', month_ago, month_ago).count
    audio_recording_total_duration = AudioRecording.sum(:duration_seconds)
    audio_recording_total_size = AudioRecording.sum(:data_length_bytes)

    tags_total = Tag.count
    tags_applied_total = Tagging.count

    #unannotated_audio = audio_recording_total_duration - annotations_total_duration

    @status_info = {
        storage: storage_msg,
        users_online: users_online,
        users_total: users_total,
        online_window_start: online_window,
        annotations_total: annotations_total,
        annotations_recent: annotations_recent,
        audio_recording_total: audio_recording_total,
        audio_recording_recent: audio_recording_recent,
        audio_recording_total_duration: audio_recording_total_duration,
        audio_recording_total_size: audio_recording_total_size,
        tags_total: tags_total,
        tags_applied_total: tags_applied_total
    }

    if current_user.blank?
      @recent_audio_events = AudioEvent.order('audio_events.updated_at DESC').limit(7)
    elsif current_user.has_role? :admin
      @recent_audio_events = AudioEvent.includes(:audio_recording, :updater).order('audio_events.updated_at DESC').limit(20)
    else
      @recent_audio_events = current_user.accessible_audio_events.includes(:audio_recording, :updater).order('audio_events.updated_at DESC').limit(7)
    end

    respond_to do |format|
      format.html
      format.json { render json: @status_info }
    end
  end


end