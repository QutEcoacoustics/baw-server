# frozen_string_literal: true

# home pages and landing pages
class PublicController < ApplicationController
  SKIP_AUTH_FOR = [
    :index,
    :website_status,
    :credits,
    :disclaimers,
    :ethics_statement,
    :data_upload,

    :new_contact_us, :create_contact_us,
    :new_bug_report, :create_bug_report,
    :new_data_request, :create_data_request,

    :cors_preflight
  ].freeze

  skip_authorization_check only: SKIP_AUTH_FOR

  def should_authenticate_user?
    return false if SKIP_AUTH_FOR.include?(action_sym)

    super
  end

  # ensure that invalid CORS preflight requests get useful responses
  skip_before_action :verify_authenticity_token, only: :cors_preflight

  # Allows rendering CMS blobs
  # TODO: remove when rails views removed
  include ComfortableMexicanSofa::RenderMethods
  helper Comfy::CmsHelper
  helper CmsHelpers

  def index
    base_path = "#{Rails.root}/public"
    image_base = '/system/home/'
    json_data_file = "#{base_path}#{image_base}animals.json"
    sensor_tree = "#{base_path}#{image_base}sensor_tree.jpg"
    if File.exist?(json_data_file) && File.exist?(sensor_tree)
      species_data = JSON.parse(File.read(json_data_file))
      item_count = species_data['species'].size
      item_index = rand(item_count)
      # select a random image with audio and sensor tree
      @selected_images = {
        animal: species_data['species'][item_index],
        sensor_tree: "#{image_base}sensor_tree.jpg",
        image_base: "#{image_base}media/",
        example_spectrogram: "#{image_base}spectrogram_example.jpg",
        ecologist: "#{image_base}eco.jpg"
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

  def website_status
    result = StatsController.fetch_stats(current_user)
    @status_info = result[:summary]
    # use .includes to eager load associations
    @recent_audio_recordings =
      result
      .dig(:recent, :audio_recordings)
      &.includes([:creator, { site: :projects }])
    @recent_audio_events =
      result
      .dig(:recent, :audio_events)
      .includes([:updater, { audio_recording: :site }])

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
      attribute: :recaptcha
    )

    respond_to do |format|
      if recaptcha_valid && model_valid
        PublicMailer.contact_us_message(current_user, @contact_us, request).deliver_now
        format.html {
          redirect_to contact_us_path,
            notice: "Thank you for contacting us. If you've asked us to contact you or " \
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
      attribute: :recaptcha
    )

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
      attribute: :recaptcha
    )

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
    # Authentication and authorization are not checked
    # this method caters for all MALFORMED OPTIONS requests.
    # it will not be used for valid OPTIONS requests
    # valid OPTIONS requests will be caught by the rails-cors gem (see application.rb)
    raise CustomErrors::BadRequestError,
      "CORS preflight request to '#{params[:requested_route]}' was not valid. Required headers: Origin, Access-Control-Request-Method. Optional headers: Access-Control-Request-Headers."
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
          predicate: ->(_user) { action_name == 'disclaimers' }
        },
        {
          title: 'baw.shared.links.credits.title',
          href: credits_path,
          tooltip: 'baw.shared.links.credits.description',
          icon: nil,
          indentation: 0,
          predicate: ->(_user) { action_name == 'credits' }
        },
        {
          title: 'baw.shared.links.ethics_statement.title',
          href: ethics_statement_path,
          tooltip: 'baw.shared.links.ethics_statement.description',
          icon: nil,
          indentation: 0,
          predicate: ->(_user) { action_name == 'ethics_statement' }
        }
      ]
    }
  end

  private

  def annotation_download
    selected_params = annotation_download_params

    selected_project_id = selected_params[:selected_project_id]
    selected_site_id = selected_params[:selected_site_id]
    selected_user_id = selected_params[:selected_user_id]
    selected_timezone_name = selected_params[:selected_timezone_name]

    @annotation_download = nil

    if selected_project_id.present? && selected_site_id.present?

      # only accessible if current user has show access to project
      # and site is in specified project
      project_id = selected_project_id.to_i
      project = Project.find(project_id)
      site_id = selected_site_id.to_i
      site = Site.find(site_id)
      msg = "You must have access to the site (#{site.id}) and project(s) (#{site.projects.pluck(:id).join(', ')}) to download annotations."
      raise CanCan::AccessDenied.new(msg, :show, site) if project.nil? || site.nil?
      raise CanCan::AccessDenied.new(msg, :show, site) unless Access::Core.can?(current_user, :reader, project)

      Access::Core.check_orphan_site!(site)
      unless Access::Core.can_any?(current_user, :reader, site.projects)
        raise CanCan::AccessDenied.new(msg, :show, site)
      end
      raise CanCan::AccessDenied.new(msg, :show, site) unless project.sites.pluck(:id).include?(site_id)

      @annotation_download = {
        link: download_site_audio_events_path(project_id, site_id, selected_timezone_name:),
        name: site.name,
        timezone_name: selected_timezone_name
      }

    elsif selected_user_id.present?

      user_id = selected_user_id.to_i
      user = User.find(user_id)
      is_same_user = User.same_user?(current_user, user)
      msg = 'Only admins and annotation creators can download annotations created by a user.'
      raise CanCan::AccessDenied.new(msg, :show, AudioEvent) if user.nil?
      raise CanCan::AccessDenied.new(msg, :show, AudioEvent) if !Access::Core.is_admin?(current_user) && !is_same_user

      @annotation_download = {
        link: download_user_audio_events_path(user_id, selected_timezone_name:),
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
      :selected_timezone_name
    )
  end
end
