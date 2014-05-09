class PublicController < ApplicationController
  layout 'public', except: [:index]
  layout 'application', only: [:index]

  skip_authorization_check only: [
      :index, :status, :website_status,
      :new_contact_us, :create_contact_us,
      :new_bug_report, :create_bug_report,
      :new_data_request, :create_data_request,
      :credits, :ethics_statement, :disclaimers
  ]

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

    order_by_coalesce = 'COALESCE(audio_events.updated_at, audio_events.created_at) DESC'

    if current_user.blank?
      @recent_audio_events = AudioEvent.order(order_by_coalesce).limit(7)
    elsif current_user.has_role? :admin
      @recent_audio_events = AudioEvent.includes(:audio_recording, :updater).order(order_by_coalesce).limit(20)
    else
      @recent_audio_events = current_user.accessible_audio_events.includes(:audio_recording, :updater).order(order_by_coalesce).limit(7)
    end

    respond_to do |format|
      format.html
      format.json { render json: @status_info }
    end
  end

  # GET /credits
  def credits

  end

  # GET /disclaimers
  def disclaimers

  end

  # GET /ethics_statement
  def ethics_statement

  end

  # GET /contact_us
  def new_contact_us
    @contact_us = ContactUs.new
    respond_to do |format|
      format.html {}
    end
  end

  # POST /contact_us
  def create_contact_us
    @contact_us = ContactUs.new(params[:contact_us])

    model_valid = @contact_us.valid?
    recaptcha_valid = verify_recaptcha(
        model: @contact_us,
        message: 'Captcha response was not correct. Please try again.',
        attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.contact_us_message(current_user, @contact_us, request)
        format.html {
          redirect_to contact_us_path,
                      notice: "Thank you for contacting us. If you've asked us to contact you or " +
                          'we need more information, we will be in touch with you shortly.'
        }
      else
        format.html {
          render action: 'new_contact_us'
        }
      end
    end
  end

  # GET /bug_report
  def new_bug_report
    @bug_report = BugReport.new
    respond_to do |format|
      format.html {}
    end
  end

  # POST /bug_report
  def create_bug_report
    @bug_report = BugReport.new(params[:bug_report])

    model_valid = @bug_report.valid?
    recaptcha_valid = verify_recaptcha(
        model: @bug_report,
        message: 'Captcha response was not correct. Please try again.',
        attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.bug_report_message(current_user, @bug_report, request)
        format.html {
          redirect_to bug_report_path,
                      notice: 'Thank you, your report was successfully submitted.
 If you entered an email address, we will let you know if the problems you describe are resolved.'
        }
      else
        format.html {
          render action: 'new_bug_report'
        }
      end
    end
  end

  # GET /data_request
  def new_data_request
    @data_request = DataRequest.new
    respond_to do |format|
      format.html {}
    end
  end

  # POST /data_request
  def create_data_request
    @data_request = DataRequest.new(params[:data_request])

    model_valid = @data_request.valid?
    recaptcha_valid = verify_recaptcha(
        model: @data_request,
        message: 'Captcha response was not correct. Please try again.',
        attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.data_request_message(current_user, @data_request, request)
        format.html {
          redirect_to data_request_path,
                      notice: 'Your request was successfully submitted. We will be in contact shortly.'
        }
      else
        format.html {
          render action: 'new_data_request'
        }
      end
    end
  end

end