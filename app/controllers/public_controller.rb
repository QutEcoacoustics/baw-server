class PublicController < ApplicationController
  skip_authorization_check only: [
      :index, :status,
      :website_status,
      :credits,
      :disclaimers,
      :ethics_statement,
      :data_upload,

      :new_contact_us, :create_contact_us,
      :new_bug_report, :create_bug_report,
      :new_data_request, :create_data_request,

      :cors_preflight
  ]

  # ensure that invalid CORS preflight requests get useful responses
  skip_before_action :verify_authenticity_token, only: :cors_preflight

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

    @random_projects = Access::ByPermission
                           .projects(current_user)
                           .includes(:creator)
                           .references(:creator)
                           .order('RANDOM()')
                           .take(3)

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
    users_online = User.where('last_seen_at > ? OR current_sign_in_at > ? OR last_sign_in_at > ?', online_window, online_window, online_window).count
    users_total = User.count

    month_ago = 1.month.ago
    annotations_total = AudioEvent.count
    annotations_recent = AudioEvent.where('created_at > ? OR updated_at > ?', month_ago, month_ago).count
    annotations_total_duration = AudioEvent.sum('end_time_seconds - start_time_seconds').to_f
    annotations_total_duration = 0 if annotations_total_duration.blank?

    audio_recording_total = AudioRecording.count
    audio_recording_recent = AudioRecording.where('created_at > ?', month_ago).count

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

  def data_upload
    respond_to do |format|
      format.html
    end
  end

  # GET /contact_us
  def new_contact_us
    @contact_us = DataClass::ContactUs.new
    respond_to do |format|
      format.html {}
    end
  end

  # POST /contact_us
  def create_contact_us
    @contact_us = DataClass::ContactUs.new(params[:data_class_contact_us])

    model_valid = @contact_us.valid?
    recaptcha_valid = verify_recaptcha(
        action: 'contact_us',
        model: @contact_us,
        message: 'Captcha response was not correct. Please try again.',
        attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.contact_us_message(current_user, @contact_us, request).deliver_now
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
    @bug_report = DataClass::BugReport.new
    respond_to do |format|
      format.html {}
    end
  end

  # POST /bug_report
  def create_bug_report
    @bug_report = DataClass::BugReport.new(params[:data_class_bug_report])

    model_valid = @bug_report.valid?
    recaptcha_valid = verify_recaptcha(
      action: 'bug_report',
      model: @bug_report,
      message: 'Captcha response was not correct. Please try again.',
      attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.bug_report_message(current_user, @bug_report, request).deliver_now
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
    @data_request = DataClass::DataRequest.new

    annotation_download

    respond_to do |format|
      format.html {}
    end
  end

  # POST /data_request
  def create_data_request
    @data_request = DataClass::DataRequest.new(params[:data_class_data_request])

    model_valid = @data_request.valid?
    recaptcha_valid = verify_recaptcha(
      action: 'data_request',
      model: @data_request,
      message: 'Captcha response was not correct. Please try again.',
      attribute: :recaptcha)

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.data_request_message(current_user, @data_request, request).deliver_now
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

  def cors_preflight
    # Authentication and authorisation are not checked
    # this method caters for all MALFORMED OPTIONS requests.
    # it will not be used for valid OPTIONS requests
    # valid OPTIONS requests will be caught by the rails-cors gem (see application.rb)
    fail CustomErrors::BadRequestError, "CORS preflight request to '#{params[:requested_route]}' was not valid. Required headers: Origin, Access-Control-Request-Method. Optional headers: Access-Control-Request-Headers."
  end

  def nav_menu
    {
        #anchor_after: 'baw.shared.links.home.title',
        menu_items: [
            {
                title: 'baw.shared.links.disclaimers.title',
                href: disclaimers_path,
                tooltip: 'baw.shared.links.disclaimers.description',
                icon: nil,
                indentation: 0,
                predicate: lambda { |user| action_name == 'disclaimers' }
            },
            {
                title: 'baw.shared.links.credits.title',
                href: credits_path,
                tooltip: 'baw.shared.links.credits.description',
                icon: nil,
                indentation: 0,
                predicate: lambda { |user| action_name == 'credits' }
            },
            {
                title: 'baw.shared.links.ethics_statement.title',
                href: ethics_statement_path,
                tooltip: 'baw.shared.links.ethics_statement.description',
                icon: nil,
                indentation: 0,
                predicate: lambda { |user| action_name == 'ethics_statement' }
            }
        ]
    }
  end

  private

  def recent_audio_recordings
    order_by_coalesce = 'COALESCE(audio_recordings.updated_at, audio_recordings.created_at) DESC'

    if current_user.blank?
      @recent_audio_recordings = AudioRecording.order(order_by_coalesce).limit(7)
    else
      @recent_audio_recordings = Access::ByPermission.audio_recordings(current_user, Access::Core.levels).includes(site: :projects).order(order_by_coalesce).limit(10)
    end

  end

  def recent_audio_events
    order_by_coalesce = 'COALESCE(audio_events.updated_at, audio_events.created_at) DESC'

    if current_user.blank?
      @recent_audio_events = AudioEvent
                                 .order(order_by_coalesce)
                                 .limit(7)
    elsif Access::Core.is_admin?(current_user)
      @recent_audio_events = AudioEvent
                                 .includes([:creator, audio_recording: {site: :projects}])
                                 .order(order_by_coalesce)
                                 .limit(10)
    else
      @recent_audio_events = Access::ByPermission
                                 .audio_events(current_user, Access::Core.levels)
                                 .includes([:updater, audio_recording: :site])
                                 .order(order_by_coalesce).limit(10)
    end

  end

  def annotation_download
    selected_params = annotation_download_params

    selected_project_id = selected_params[:selected_project_id]
    selected_site_id = selected_params[:selected_site_id]
    selected_user_id = selected_params[:selected_user_id]
    selected_timezone_name = selected_params[:selected_timezone_name]

    @annotation_download = nil

    if !selected_project_id.blank? && !selected_site_id.blank?

      # only accessible if current user has show access to project
      # and site is in specified project
      project_id = selected_project_id.to_i
      project = Project.find(project_id)
      site_id = selected_site_id.to_i
      site = Site.find(site_id)
      msg = "You must have access to the site (#{site.id}) and project(s) (#{site.projects.pluck(:id).join(', ')}) to download annotations."
      fail CanCan::AccessDenied.new(msg, :show, site) if project.nil? || site.nil?
      fail CanCan::AccessDenied.new(msg, :show, site) unless Access::Core.can?(current_user, :reader, project)
      Access::Core.check_orphan_site!(site)
      fail CanCan::AccessDenied.new(msg, :show, site) unless Access::Core.can_any?(current_user, :reader, site.projects)
      fail CanCan::AccessDenied.new(msg, :show, site) unless project.sites.pluck(:id).include?(site_id)

      @annotation_download = {
          link: download_site_audio_events_path(project_id, site_id, selected_timezone_name: selected_timezone_name),
          name: site.name,
          timezone_name: selected_timezone_name
      }

    elsif !selected_user_id.blank?

      user_id = selected_user_id.to_i
      user = User.find(user_id)
      is_same_user = User.same_user?(current_user, user)
      msg = 'Only admins and annotation creators can download annotations created by a user.'
      fail CanCan::AccessDenied.new(msg, :show, AudioEvent) if user.nil?
      fail CanCan::AccessDenied.new(msg, :show, AudioEvent) if !Access::Core.is_admin?(current_user) && !is_same_user

      @annotation_download = {
          link: download_user_audio_events_path(user_id, selected_timezone_name: selected_timezone_name),
          name: user.user_name,
          timezone_name: selected_timezone_name
      }
    end
  end

  def annotation_download_params
    params.permit(
        :selected_project_id,
        :selected_site_id,
        :selected_user_id,
        :selected_timezone_name)
  end


end
