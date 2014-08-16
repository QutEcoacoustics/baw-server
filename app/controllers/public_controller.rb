class PublicController < ApplicationController
  layout 'public'

  skip_authorization_check only: [
      :index, :status, :website_status, :audio_recording_catalogue,
      :recent_annotations, :recent_audio_recordings,
      :new_contact_us, :create_contact_us,
      :new_bug_report, :create_bug_report,
      :new_data_request, :create_data_request,
      :credits, :ethics_statement, :disclaimers,
      :test_exceptions
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

    #storage_msg = AudioRecording.check_storage

    online_window = 2.hours.ago
    users_online = User.where('current_sign_in_at > ? OR last_sign_in_at > ?', online_window, online_window).count
    users_total = User.count

    month_ago = 1.month.ago
    annotations_total = AudioEvent.count
    annotations_recent = AudioEvent.where('created_at > ? OR updated_at > ?', month_ago, month_ago).count
    annotations_total_duration = AudioEvent.sum('end_time_seconds - start_time_seconds').to_f
    annotations_total_duration = 0 if annotations_total_duration.blank?

    audio_recording_total = AudioRecording.count
    audio_recording_recent = AudioRecording.where('created_at > ? OR updated_at > ?', month_ago, month_ago).count

    audio_recording_total_duration = AudioRecording.sum(:duration_seconds)
    audio_recording_total_duration = 0 if audio_recording_total_duration.blank?

    audio_recording_total_size = AudioRecording.sum(:data_length_bytes)
    audio_recording_total_size = 0 if audio_recording_total_size.blank?

    tags_total = Tag.count
    tags_applied_total = Tagging.count

    #percent_annotated = annotations_total_duration.to_f / audio_recording_total_duration.to_f * 100

    #unannotated_audio = audio_recording_total_duration - annotations_total_duration

    @status_info = {
        #storage: storage_msg,
        users_online: users_online,
        users_total: users_total,
        online_window_start: online_window,
        annotations_total: annotations_total,
        annotations_total_duration: annotations_total_duration,
        annotations_recent: annotations_recent,
        audio_recording_total: audio_recording_total,
        audio_recording_recent: audio_recording_recent,
        audio_recording_total_duration: audio_recording_total_duration,
        audio_recording_total_size: audio_recording_total_size,
        tags_total: tags_total,
        tags_applied_total: tags_applied_total,
        #percent_annotated: percent_annotated
    }

    recent_audio_recordings
    recent_audio_events

    respond_to do |format|
      format.html
      format.json { render json: @status_info }
    end
  end

  def audio_recording_catalogue

    respond_to do |format|
      #format.html
      format.json {

        if !current_user.blank? && current_user.is_admin?

        else

          unless params[:projectId].blank?
            project = Project.where(id: params[:projectId]).first

            if project.blank?
              fail CustomErrors::ItemNotFoundError, 'Project not found from audio_recording_catalogue'
            end

            if current_user.blank? || !current_user.can_read?(project)
              fail CanCan::AccessDenied, 'Project access denied from audio_recording_catalogue'
            end
          end

          unless params[:siteId].blank?
            site = Site.where(id: params[:siteId]).first

            if site.blank?
              fail CustomErrors::ItemNotFoundError, 'Site not found from audio_recording_catalogue'
            end

            projects = Site.where(id: params[:siteId]).first.projects
            if current_user.blank? || !current_user.can_read_any?(projects)
              fail CanCan::AccessDenied, 'Site access denied from audio_recording_catalogue'
            end
          end
        end

        query = AudioRecording.joins(site: :projects)
        .select(
            'count(*) as grouped_count,
EXTRACT(YEAR FROM recorded_date) as extracted_year,
EXTRACT(MONTH FROM recorded_date) as extracted_month,
EXTRACT(DAY FROM recorded_date) as extracted_day')

        if !params[:projectId].blank? && !current_user.blank?
          query = query.where('projects_sites.project_id = ?', params[:projectId])
        end

        if !params[:siteId].blank? && !current_user.blank?
          query = query.where(site_id: params[:siteId])
        end

        audio_recordings_grouped = query
        .group('extracted_year, extracted_month, extracted_day')
        .map { |ar|
          {
              count: ar.grouped_count,
              extracted_year: ar.extracted_year,
              extracted_month: ar.extracted_month.rjust(2, '0'),
              extracted_day: ar.extracted_day.rjust(2, '0')
          }
        }
        render json: audio_recordings_grouped }
    end
  end

  # GET /credits
  def credits
    respond_to do |format|
      format.html
    end
  end

  # GET /disclaimers
  def disclaimers
    respond_to do |format|
      format.html
    end
  end

  # GET /ethics_statement
  def ethics_statement
    respond_to do |format|
      format.html
    end
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

    @annotation_download = nil
    if !params[:annotation_download].blank? &&
        !params[:annotation_download][:project_id].blank? &&
        !params[:annotation_download][:site_id].blank?
      @annotation_download = {
          link: download_site_audio_events_path(params[:annotation_download][:project_id], params[:annotation_download][:site_id]),
          name: params[:annotation_download][:name]
      }
    end

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

  def test_exceptions
    if ENV['RAILS_ENV'] == 'test'
      if params.include?(:exception_class)
        msg = 'Purposeful exception raised for testing.'
        error_class_string = params[:exception_class]
        error_class = error_class_string.constantize

        case error_class_string
          when 'ActiveResource::BadRequest'
            fail error_class.new(response)

          when 'ActiveRecord::RecordNotUnique'
            fail error_class.new(msg, nil)

          when 'CustomErrors::UnsupportedMediaTypeError',
              'ActiveResource::BadRequest',
              'CustomErrors::NotAcceptableError',
              'CustomErrors::RoutingArgumentError'
            fail error_class.new(msg)

          else
            fail error_class
        end

      end
    end
  end


  private

  def recent_audio_recordings
    order_by_coalesce = 'COALESCE(audio_recordings.updated_at, audio_recordings.created_at) DESC'

    if current_user.blank?
      @recent_audio_recordings = AudioRecording.order(order_by_coalesce).limit(7)
    elsif current_user.has_role? :admin
      @recent_audio_recordings = AudioRecording.includes(site: :projects).order(order_by_coalesce).limit(10)
    else
      @recent_audio_recordings = current_user.accessible_audio_recordings.includes(site: :projects).order(order_by_coalesce).limit(10)
    end

  end

  def recent_audio_events
    order_by_coalesce = 'COALESCE(audio_events.updated_at, audio_events.created_at) DESC'

    if current_user.blank?
      @recent_audio_events = AudioEvent.order(order_by_coalesce).limit(7)
    elsif current_user.has_role? :admin
      @recent_audio_events = AudioEvent.includes([:updater, audio_recording: :site]).order(order_by_coalesce).limit(10)
    else
      @recent_audio_events = current_user.accessible_audio_events.includes([:updater, audio_recording: :site]).order(order_by_coalesce).limit(10)
    end

  end

end