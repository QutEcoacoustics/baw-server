# frozen_string_literal: true

# Defines permissions for controller actions.
class Ability
  include CanCan::Ability

  # Define abilities for user.
  # @param [User] user
  # @return [void]
  def initialize(user)
    # ======== Reset Actions ========

    # clear all aliased actions - these mappings are removed:
    #   alias_action :index, :show, :to => :read
    #   alias_action :new, :to => :create
    #   alias_action :edit, :to => :update

    clear_aliased_actions

    # ======== Information about specifying `can` on controller actions ========

    #                                               | Can be used in |
    # HTTP Verb   | Path                | Action    | a block?       | Purpose
    #-------------|---------------------|-----------|----------------------------------------
    # GET         | /projects           | :index    | NO             | display a list of all projects
    # GET         | /projects/new       | :new      | YES            | return an HTML form/json properties for creating a new project
    # POST        | /projects           | :create   | YES            | create a new project
    # GET         | /projects/:id       | :show     | YES            | display a specific project
    # GET         | /projects/:id/edit  | :edit     | YES            | return an HTML form for editing a project (not relevant to json API)
    # PUT         | /projects/:id       | :update   | YES            | update a specific project
    # DELETE      | /projects/:id       | :destroy  | YES            | delete a specific project
    # POST or GET | /projects/filter    | :filter   | NO             | advanced filtering endpoint (json API only)

    # WARNING: If a block or hash of conditions exist they will be ignored
    # when checking on a class, and it will return true.
    # Think of it as asking "can the current user read *a* project?" when using a class,
    # and "can the current user read *this* project?" when checking an instance.
    # This is mainly relevant for :index and :filter
    # since they do no have an instance of the model.

    # WARNING: :manage represents ANY action on the object.
    # DO NOT use :manage except for the admin user

    # WARNING: instance variable in controller index action will not be set if using a block for can definitions
    # because there is no way to determine which records to fetch from the database.

    # WARNING: can't add .includes to permission checks
    # it breaks when validating projects due to ActiveRecord::AssociationRelation
    # .all would have worked. I tried .where(nil), that didn't work either :/
    # https://github.com/rails/rails/issues/12756
    # https://github.com/plataformatec/has_scope/issues/41

    # ======== Conventions and Notes ========

    #  - index and filter permissions are checked as part of filter query
    #  - new is usually available publicly
    #  - never use `current_user`
    #  - `user` may not be the logged in user

    # ======== Permissions Specification ========

    # See specification description on baw-server wiki:
    # https://github.com/QutBioacoustics/baw-server/wiki/Permissions

    # either current logged in user or guest user (not logged in)
    # an unconfirmed user is logged in and is not a guest
    user = create_guest_user if user.blank?

    # guest access is specified per project
    is_guest = Access::Core.is_guest?(user)

    # api security endpoints for logged in users
    can [:show, :destroy], :api_security unless is_guest

    to_cms(user, is_guest)

    if Access::Core.is_admin?(user)
      for_admin

    elsif Access::Core.is_harvester?(user)
      for_harvester

    elsif Access::Core.is_standard_user?(user) || is_guest
      # available models:
      # Project, Permission, Site, AudioRecording,
      # AudioEvent, AudioEventComment, Bookmark,
      # AnalysisJob, SavedSearch, Script, Tag, Tagging,
      # User

      to_project(user, is_guest)
      to_permission(user)
      to_harvest(user, is_guest)
      to_harvest_item(user, is_guest)
      to_region(user, is_guest)
      to_site(user, is_guest)
      to_audio_recording(user, is_guest)
      to_audio_event(user, is_guest)
      to_audio_event_import(user, is_guest)
      to_audio_event_import_file(user, is_guest)
      to_audio_event_comment(user, is_guest)
      to_bookmark(user, is_guest)
      to_analysis_job(user, is_guest)
      to_analysis_jobs_item(user)
      to_dataset(user, is_guest)
      to_dataset_item(user, is_guest)
      to_progress_event(user, is_guest)
      to_saved_search(user, is_guest)
      to_provenance(user, is_guest)
      to_script(user, is_guest)
      to_tag(user, is_guest)
      to_tagging(user, is_guest)
      to_user(user, is_guest)
      to_verification(user, is_guest)

      to_analysis(user, is_guest)
      to_media(user, is_guest)
      to_error(user, is_guest)
      to_public(user, is_guest)

      to_study(user, is_guest)
      to_question(user, is_guest)
      to_response(user, is_guest)
      to_report(user, is_guest)
    else
      raise ArgumentError, "Permissions are not defined for user '#{user.id}': #{user.role_symbols}"

    end

    # internal takes permissions away from admin, it has to be after all of the above
    for_internal(is_guest)
  end

  private

  def check_model(model)
    raise ArgumentError, 'Must have an instance of the model.' if model.nil?
    #fail CustomErrors::UnprocessableEntityError.new('Model was invalid.', model.errors) if model.invalid?
  end

  def to_report(_user, _is_guest)
    can [:summary], :reports
  end

  def to_cms(user, _is_guest)
    alias_action :index, :show, to: :read
    alias_action :create, :update, to: :manage

    can [:read, :manage], 'Cms::Site' if Access::Core.is_admin?(user)

    # anyone anytime can read cms blobs
    can [:read], 'Cms::Site'
  end

  def for_internal(is_guest)
    # internal endpoints for hooks explicitly require no user information to have been set
    [
      # add more here
      :internal_sftpgo
    ].each do |subject|
      if is_guest
        can [:manage], subject do |_subject, remote_ip|
          Settings.internal_allow_remote_ip?(remote_ip)
        end
      else
        cannot [:manage], subject
      end
    end
  end

  def for_admin
    # admin can access any action on any controller
    can :manage, :all

    # no one is allowed to change allow_audio_upload except an admin
    can [:allow_audio_upload], Project

    can [:download_hidden_files], AnalysisJobsItem
  end

  def for_harvester
    # actions used for harvesting. See baw-workers.
    # :original is the permission to download an original audio file
    can [:new, :create, :check_uploader, :update_status, :update, :original], AudioRecording
    can [:index], :downloader

    # omitted: :new, :create,
    # applied by default: :index, :filter
    can [:show, :invoke], AnalysisJobsItem
  end

  def create_guest_user
    guest = User.new
    guest.roles << :guest
    guest
  end

  def check_audio_event(user, site, audio_event)
    Access::Core.check_orphan_site!(site)
    projects = site.projects
    is_ref = audio_event.is_reference
    Access::Core.can_any?(user, :reader, projects) || is_ref
  end

  def to_project(user, is_guest)
    # cannot use block for #index, #filter, #new_access_request, #submit_access_request
    # GET|POST  /projects/filter                 projects#filter {:format=>"json"}
    # POST      /projects/:id/update_permissions projects#update_permissions
    # GET       /projects/:id/edit_sites         projects#edit_sites
    # PATCH|PUT /projects/:id/update_sites       projects#update_sites
    # GET       /projects/new_access_request     projects#new_access_request
    # POST      /projects/submit_access_request  projects#submit_access_request
    # GET       /projects                        projects#index
    # POST      /projects                        projects#create
    # GET       /projects/new                    projects#new
    # GET       /projects/:id/edit               projects#edit
    # GET       /projects/:id                    projects#show
    # PATCH|PUT /projects/:id                    projects#update
    # DELETE    /projects/:id                    projects#destroy

    # any user, including guest, with reader permissions can #show a project
    can [:show], Project do |project|
      check_model(project)
      Access::Core.can?(user, :reader, project)
    end

    # only admin can #edit_sites, #update_sites (update_sites is html-only)
    # below definition is redundant but added for clarity
    can [:update_sites], Project do |project|
      check_model(project)
      Access::Core.is_admin?(user)
    end

    # TODO: update_sites will be merged with sites#orphans

    # must be owner to do these actions
    # :update_permissions is html-only
    # :creates_sites:  Can we create a site that belongs to this project? This is mainly used in views
    can [:edit, :update, :update_permissions, :destroy, :create_sites], Project do |project|
      check_model(project)
      Access::Core.can?(user, :owner, project)
    end

    # actions any logged in user can access
    can [:new_access_request, :submit_access_request], Project unless is_guest

    # Restricted to Admin according to settings (admin has implicit access)
    can [:create], Project unless is_guest || !Settings.permissions.any_user_can_create_projects

    # available to any user, including guest
    can [:index, :filter, :new], Project
  end

  def to_permission(user)
    # cannot use block for #index
    # #show, #create, #delete are only used by json api
    # #edit and #update are done via project instead
    # GET    /projects/:project_id/permissions     permissions#index
    # POST   /projects/:project_id/permissions     permissions#create {:format=>"json"}
    # GET    /projects/:project_id/permissions/new permissions#new {:format=>"json"}
    # GET    /projects/:project_id/permissions/:id permissions#show {:format=>"json"}
    # DELETE /projects/:project_id/permissions/:id permissions#destroy {:format=>"json"}

    # only owners can show, change, or remove permissions
    can [:show, :create, :update, :destroy], Permission do |permission|
      check_model(permission)
      Access::Core.can?(user, :owner, permission.project)
    end

    # available to any user, including guest
    can [:index, :filter, :new], Permission
  end

  def to_harvest(user, _is_guest)
    # POST      /projects/:project_id/harvests                         harvests#create
    # GET       /projects/:project_id/harvests/new                     harvests#new
    # GET       /projects/:project_id/harvests/:id                     harvests#show
    # PATCH|PUT /projects/:project_id/harvests/:id                     harvests#update
    # DELETE    /projects/:project_id/harvests/:id                     harvests#destroy
    # GET       /projects/:project_id/harvests                         harvests#index {:format=>"json"}
    # GET|POST  /projects/:project_id/harvests/filter                                       harvests#filter {:format=>"json"}
    # and all of the above again with the shallow route

    # only owner of the project can access these actions.
    # Special action :harvest_audio used as validation in the harvester job
    can [:create, :update, :destroy, :show, :harvest_audio], Harvest do |harvest|
      check_model(harvest)
      Access::Core.can_any?(user, :owner, harvest.project)
    end

    # available to any user, including guest
    can [:index, :filter, :new], Harvest
  end

  def to_harvest_item(_user, _is_guest)
    # available to any user, including guest
    can [:index, :filter], HarvestItem
  end

  def to_region(user, _is_guest)
    # POST      /projects/:project_id/regions                         regions#create
    # GET       /projects/:project_id/regions/new                     regions#new
    # GET       /projects/:project_id/regions/:id                     regions#show
    # PATCH|PUT /projects/:project_id/regions/:id                     regions#update
    # DELETE    /projects/:project_id/regions/:id                     regions#destroy
    # GET       /projects/:project_id/regions                         regions#index {:format=>"json"}
    # GET|POST  /regions/filter                                       regions#filter {:format=>"json"}
    # and all of the above again with the shallow route

    # any user, including guest, with reader permissions on project can #show a region and access #new
    can [:show], Region do |region|
      check_model(region)
      Access::Core.can_any?(user, :reader, region.project)
    end

    # only owner can access these actions.
    can [:create, :update, :destroy], Region do |region|
      check_model(region)
      Access::Core.can_any?(user, :owner, region.project)
    end

    # available to any user, including guest
    can [:index, :filter, :new], Region
  end

  def to_site(user, _is_guest)
    # only admin can :destroy, :orphans

    # cannot use block for #index, #filter, #orphans
    # only admin can access #orphans
    # GET       /projects/:project_id/sites/:id/upload_instructions sites#upload_instructions
    # GET       /projects/:project_id/sites/:id/harvest             sites#harvest
    # POST      /projects/:project_id/sites                         sites#create
    # GET       /projects/:project_id/sites/new                     sites#new
    # GET       /projects/:project_id/sites/:id/edit                sites#edit
    # GET       /projects/:project_id/sites/:id                     sites#show
    # PATCH|PUT /projects/:project_id/sites/:id                     sites#update
    # DELETE    /projects/:project_id/sites/:id                     sites#destroy
    # GET       /projects/:project_id/sites                         sites#index {:format=>"json"}
    # GET|POST  /sites/filter                                       sites#filter {:format=>"json"}
    # GET       /sites/orphans                                      sites#orphans
    # GET       /sites/:id                                          sites#show_shallow {:format=>"json"}

    # any user, including guest, with reader permissions on project can #show a site and access #new
    can [:show, :show_shallow], Site do |site|
      check_model(site)
      Access::Core.check_orphan_site!(site)
      # can't add .includes here - it breaks when validating projects due to ActiveRecord::AssociationRelation
      Access::Core.can_any?(user, :reader, site.projects)
    end

    # only owner can access these actions.
    # :create (create a new site in a project) requires an instance to be available before permissions are checked.
    # This is done in controller action.
    # Note: duplicate definition :create_sites in project abilities above used for rendering view capabilities.
    can [:create, :edit, :update, :destroy, :upload_instructions, :harvest], Site do |site|
      check_model(site)
      Access::Core.check_orphan_site!(site)
      Access::Core.can_any?(user, :owner, site.projects)
    end

    # available to any user, including guest
    can [:index, :filter, :new], Site
  end

  def to_audio_recording(user, _is_guest)
    # cannot use block for #index, #filter
    # See permissions for harvester (#for_harvester)
    #   - Only admin and harvester can #create, #check_uploader, #update_status, #update
    # permissions are also checked in controller actions
    # GET       /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id audio_recordings#check_uploader {:format=>"json"}
    # POST      /projects/:project_id/sites/:site_id/audio_recordings                             audio_recordings#create {:format=>"json"}
    # GET       /projects/:project_id/sites/:site_id/audio_recordings/new                         audio_recordings#new {:format=>"json"}
    # GET|POST  /audio_recordings/filter                                                          audio_recordings#filter {:format=>"json"}
    # GET       /audio_recordings                                                                 audio_recordings#index {:format=>"json"}
    # GET       /audio_recordings/new                                                             audio_recordings#new {:format=>"json"}
    # GET       /audio_recordings/:id                                                             audio_recordings#show {:format=>"json"}
    # PATCH|PUT /audio_recordings/:id                                                             audio_recordings#update {:format=>"json"}
    # PUT       /audio_recordings/:id/update_status                                               audio_recordings#update_status {:format=>"json"}

    # any user, including guest, with reader permissions on project can #show an audio_recording
    can [:show], AudioRecording do |audio_recording|
      check_model(audio_recording)
      Access::Core.check_orphan_site!(audio_recording.site)
      Access::Core.can_any?(user, :reader, audio_recording.site.projects)
    end

    can [:new], AudioRecording do |audio_recording|
      check_model(audio_recording)
      if audio_recording.site.nil?
        # allow #new for /audio_recordings/new
        true
      else
        # require project reader for /projects/:project_id/sites/:site_id/audio_recordings/new
        Access::Core.check_orphan_site!(audio_recording.site)
        Access::Core.can_any?(user, :reader, audio_recording.site.projects)
      end
    end

    # available to any user, including guest
    can [:index, :filter], AudioRecording

    # anyone can access the downloader script
    can [:index], :downloader
  end

  def to_audio_event(user, is_guest)
    # cannot use block for #index, #filter
    # GET|POST  /audio_events/filter                                        audio_events#filter {:format=>"json"}
    # GET       /audio_recordings/:audio_recording_id/audio_events/download audio_events#download {:format=>"csv"}
    # GET       /audio_recordings/:audio_recording_id/audio_events          audio_events#index {:format=>"json"}
    # POST      /audio_recordings/:audio_recording_id/audio_events          audio_events#create {:format=>"json"}
    # GET       /audio_recordings/:audio_recording_id/audio_events/new      audio_events#new {:format=>"json"}
    # GET       /audio_recordings/:audio_recording_id/audio_events/:id      audio_events#show {:format=>"json"}
    # PATCH|PUT /audio_recordings/:audio_recording_id/audio_events/:id      audio_events#update {:format=>"json"}
    # DELETE    /audio_recordings/:audio_recording_id/audio_events/:id      audio_events#destroy {:format=>"json"}
    # GET       /projects/:project_id/audio_events/download                 audio_events#download {:format=>"csv"}
    # GET       /projects/:project_id/sites/:site_id/audio_events/download  audio_events#download {:format=>"csv"}
    # GET       /user_accounts/:user_id/audio_events/download               audio_events#download {:format=>"csv"}

    # any user, including guest, with reader permissions on project can #show an audio_event
    can [:show], AudioEvent do |audio_event|
      check_model(audio_event)
      check_audio_event(user, audio_event.audio_recording.site, audio_event)
    end

    # must have write permission or higher to create, update, destroy
    can [:create, :update, :destroy], AudioEvent do |audio_event|
      check_model(audio_event)
      Access::Core.check_orphan_site!(audio_event.audio_recording.site)
      Access::Core.can_any?(user, :writer, audio_event.audio_recording.site.projects)
    end

    # actions any logged in user can access
    # has additional auth in the controller action
    can [:download], AudioEvent unless is_guest

    # available to any user, including guest
    can [:index, :filter, :new], AudioEvent
  end

  def to_audio_event_import(user, is_guest)
    unless is_guest
      can [:create], AudioEventImport do |audio_event_import|
        check_model(audio_event_import)
        # Any user can attempt to import events...
        # But we won't import any that link to recordings they don't have write
        # access to. This is checked in the controller action.
        true
      end

      # only creator can update, destroy, show their own audio_event_imports
      can [:update, :destroy, :show, :recover], AudioEventImport, creator_id: user&.id
    end

    # available to any user
    can [:index, :filter, :new], AudioEventImport
  end

  def to_audio_event_import_file(user, is_guest)
    unless is_guest
      can [:create], AudioEventImportFile do |audio_event_import_file|
        check_model(audio_event_import_file)

        # can only add a file if you made the import as well
        next true if audio_event_import_file.audio_event_import.creator_id == user&.id

        false
      end

      # only creator can update, destroy, show their own audio_event_import_files
      can [:destroy, :show], AudioEventImportFile do |audio_event_import_file|
        check_model(audio_event_import_file)
        audio_event_import_file.audio_event_import.creator_id == user&.id
      end
    end

    # available to any user
    can [:index, :filter, :new], AudioEventImportFile
  end

  def to_audio_event_comment(user, is_guest)
    # cannot use block for #index, #filter
    # GET|POST  /audio_event_comments/filter               audio_event_comments#filter {:format=>"json"}
    # GET       /audio_events/:audio_event_id/comments     audio_event_comments#index {:format=>"json"}
    # POST      /audio_events/:audio_event_id/comments     audio_event_comments#create {:format=>"json"}
    # GET       /audio_events/:audio_event_id/comments/new audio_event_comments#new {:format=>"json"}
    # GET       /audio_events/:audio_event_id/comments/:id audio_event_comments#show {:format=>"json"}
    # PATCH|PUT /audio_events/:audio_event_id/comments/:id audio_event_comments#update {:format=>"json"}
    # DELETE    /audio_events/:audio_event_id/comments/:id audio_event_comments#destroy {:format=>"json"}

    # any user, including guest, with reader permissions on project, or for reference audio events, can #show an audio_event_comment or access #new
    can [:new, :show], AudioEventComment do |audio_event_comment|
      check_model(audio_event_comment)
      check_audio_event(user, audio_event_comment.audio_event.audio_recording.site, audio_event_comment.audio_event)
    end

    # guest users can only access #new, #show, #index, or #filter
    unless is_guest

      # can also update flag, any other attribute is restricted to creator by custom auth in controller action
      can [:create, :update], AudioEventComment do |audio_event_comment|
        check_model(audio_event_comment)
        check_audio_event(user, audio_event_comment.audio_event.audio_recording.site, audio_event_comment.audio_event)
      end

      # only logged in users can update or destroy their comments, which must be comments they created
      can [:destroy, :update], AudioEventComment, creator_id: user.id

      # available to any logged in user
      can [:filter], AudioEventComment
    end

    # available to any user, including guest
    can [:index], AudioEventComment
  end

  def to_bookmark(user, is_guest)
    # GET|POST  /bookmarks/filter bookmarks#filter {:format=>"json"}
    # GET       /bookmarks        bookmarks#index
    # POST      /bookmarks        bookmarks#create
    # GET       /bookmarks/new    bookmarks#new
    # GET       /bookmarks/:id    bookmarks#show
    # PATCH|PUT /bookmarks/:id    bookmarks#update
    # DELETE    /bookmarks/:id    bookmarks#destroy

    # guests have no access to bookmarks
    return if is_guest

    can [:create], Bookmark do |bookmark|
      check_model(bookmark)
      Access::Core.check_orphan_site!(bookmark.audio_recording.site)
      Access::Core.can_any?(user, :reader, bookmark.audio_recording.site.projects)
    end

    # only creator can update, destroy, show their own bookmarks
    can [:update, :destroy, :show], Bookmark, creator_id: user.id

    # available to any logged in user
    can [:index, :filter, :new], Bookmark
  end

  def to_analysis_job(user, _is_guest)
    can [:create], AnalysisJob do |analysis_job|
      check_model(analysis_job)

      # only admins are authorized to make system_jobs
      # no need to handle the true case, it is handle
      # by the admin allow everything
      next false if analysis_job.system_job

      Access::Core.can?(user, :writer, analysis_job.project)
    end

    can [:show], AnalysisJob do |analysis_job|
      check_model(analysis_job)

      # anyone can view a system job
      next true if analysis_job.system_job

      Access::Core.can?(user, :reader, analysis_job.project)
    end

    # only creator can update, destroy their own analysis jobs
    can [:update, :destroy, :invoke], AnalysisJob, creator_id: user.id

    # available to any user, including guest
    can [:index, :filter, :new], AnalysisJob
  end

  def to_analysis_jobs_item(user)
    # Only harvester can update - see permissions for harvester in for_harvester.

    can [:show], AnalysisJobsItem do |analysis_job_item|
      check_model(analysis_job_item)

      if analysis_job_item.audio_recording.nil?
        raise CustomErrors::BadRequestError, 'Analysis Jobs Item must have a Audio Recording.'
      end

      Access::Core.can_any?(user, :reader, analysis_job_item.audio_recording.site.projects)
    end

    # actions any logged in user can access
    can [:index, :filter], AnalysisJobsItem
  end

  def to_dataset(user, is_guest)
    # only creator can update their own dataset
    can [:update], Dataset, creator_id: user.id

    # actions any logged in user can access
    can [:create], Dataset unless is_guest

    # available to any user, including guest
    can [:new, :index, :filter, :show], Dataset
  end

  def to_dataset_item(user, _is_guest)
    # only admin can update, delete

    # only admin can create, unless it is the default dataset
    # if default dataset, must have read permission or higher to create
    can [:create], DatasetItem do |dataset_item|
      if dataset_item.dataset_id == Dataset.default_dataset_id
        check_model(dataset_item)
        Access::Core.can_any?(user, :reader, dataset_item.audio_recording.site.projects)
      else
        false
      end
    end

    # must have read permissions to show
    can [:show], DatasetItem do |dataset_item|
      check_model(dataset_item)

      if dataset_item.audio_recording.nil?
        raise CustomErrors::BadRequestError, 'Dataset Item must have a Audio Recording.'
      end

      Access::Core.check_orphan_site!(dataset_item.audio_recording.site)
      Access::Core.can_any?(user, :reader, dataset_item.audio_recording.site.projects)
    end

    # actions any logged in user can access
    can [:new, :index, :filter, :next_for_me], DatasetItem
  end

  def to_progress_event(user, _is_guest)
    # anyone can create as long as they have read access on the ancestor project of the dataset item
    can [:create], ProgressEvent do |progress_event|
      check_model(progress_event)

      # the dataset_item may not be valid and therefore may not be associated with a project
      audio_recording = progress_event.dataset_item.try(:audio_recording)
      raise CustomErrors::UnprocessableEntityError, 'Invalid dataset item' unless audio_recording

      Access::Core.can_any?(user, :reader, audio_recording.site.projects)
    end

    # must have read permissions or be creator to view
    can [:show, :index, :filter], ProgressEvent do |progress_event|
      check_model(progress_event)
      Access::Core.can_any?(user, :reader, progress_event.dataset_item.audio_recording.site.projects) ||
        progress_event.creator_id === user.id
    end

    can :new, ProgressEvent

    # update and edit are admin only
    cannot [:update, :destroy], ProgressEvent
  end

  def to_saved_search(user, is_guest)
    # cannot be updated

    # must have read permission or higher on all projects to create saved search
    can [:show, :create], SavedSearch do |saved_search|
      check_model(saved_search)
      projects = saved_search.projects
      raise CustomErrors::BadRequestError, 'Saved Search must have at least one project.' if projects.empty?

      Access::Core.can_all?(user, :reader, projects)
    end

    # only creator can destroy their own saved searches
    can [:destroy], SavedSearch, creator_id: user.id

    # actions any logged in user can access
    can [:new], SavedSearch unless is_guest

    # available to any user, including guest
    can [:index, :filter], SavedSearch
  end

  def to_provenance(_user, _is_guest)
    # other actions are admin only

    # available to any user, including guest
    can [:show, :new, :index, :filter], Provenance
  end

  def to_script(_user, is_guest)
    # only admin can manipulate scripts

    can [:show], Script unless is_guest

    # available to any user, including guest
    can [:index, :filter], Script
  end

  def to_tag(_user, is_guest)
    # cannot be updated
    # tag management controller is admin only (checked in before_action)

    # actions any logged in user can access
    can [:new, :create], Tag unless is_guest

    # available to any user, including guest
    can [:index, :show, :filter], Tag
  end

  def to_tagging(user, is_guest)
    # must have read permission or higher to show
    can [:show], Tagging do |tagging|
      check_model(tagging)
      Access::Core.check_orphan_site!(tagging.audio_event.audio_recording.site)
      Access::Core.can_any?(user, :reader, tagging.audio_event.audio_recording.site.projects)
    end

    # must have write permission or higher to create, update, destroy
    can [:create, :update, :destroy], Tagging do |tagging|
      check_model(tagging)
      Access::Core.check_orphan_site!(tagging.audio_event.audio_recording.site)
      Access::Core.can_any?(user, :writer, tagging.audio_event.audio_recording.site.projects)
    end

    # actions any logged in user can access
    can [:new, :user_index], Tagging unless is_guest

    # available to any user, including guest
    can [:index, :filter], Tagging
  end

  def to_user(user, is_guest)
    # admin only: :index, :edit
    # :edit and :update are the Admin interface for editing any user
    # normal users edit their profile using devise/registrations#edit

    # users can :update their own attributes on the user model via api
    # users can only view their own:
    can [:projects, :sites, :bookmarks, :audio_events, :audio_event_comments, :update], User, id: user.id

    # users get their own account and preferences from these actions
    can [:my_account, :modify_preferences], User, id: user.id

    # only logged in users can view a user's profile (read-only)
    can [:show, :filter], User unless is_guest
  end

  def to_analysis(_user, is_guest)
    # actions any logged in user can access
    # skips CanCan auth
    can [:show], :analysis unless is_guest
  end

  def to_media(user, is_guest)
    # available to any user, including guest
    # skips CanCan auth
    can [:show], :media

    # download original recording (#original)
    #
    # - admin and harvester can (see for_harvester and for_admin)
    # - logged in users can if the project says so
    # - anonymous users cannot
    # GET       /audio_recordings/:id/original     media#original
    return if is_guest

    can [:original], AudioRecording do |audio_recording|
      check_model(audio_recording)
      Access::Core.check_orphan_site!(audio_recording.site)
      projects = audio_recording.site.projects

      # now extract the required permission levels needed to allow original downloads
      requested_levels = projects.map(&:allow_original_download)

      Access::Core.can_any?(user, requested_levels, projects)
    end
  end

  def to_error(_user, _is_guest)
    # available to any user, including guest
    # skips CanCan auth
    can [:route_error, :uncaught_error, :test_exceptions, :show], :error

    # only available in Rails test env
    can [:test_exceptions], :error if ENV.fetch('RAILS_ENV', nil) == 'test'
  end

  def to_public(_user, _is_guest)
    # available to any user, including guest
    # skips CanCan auth
    can [
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
    ], :public
  end

  def to_study(_user, _is_guest)
    # only admin can create, update, delete

    # all users including guest can access any get request
    can [:new, :index, :filter, :show], Study
  end

  def to_question(_user, is_guest)
    can [:new], Question

    # only admin create, update, delete

    # only logged in users can view questions
    can [:index, :filter, :show], Question unless is_guest
  end

  def to_response(user, is_guest)
    can [:new], Response

    # must have read permission on dataset item to create a response for it
    can [:create], Response do |response|
      check_model(response)
      if response.dataset_item
        Access::Core.can_any?(user, :reader, response.dataset_item.audio_recording.site.projects)
      else
        false
      end
    end

    # users can only view their own responses
    # therefore guest can not view any responses
    can [:index, :filter, :show], Response, creator_id: user.id unless is_guest

    # only admin can update or delete responses
  end

  def to_verification(user, _is_guest)
    # admin can do anything, see #for_admin

    # available to any user, including guest
    can [:index, :filter, :new], Verification

    # any user, including guest, with reader permissions on project can #show a verification
    can [:show], Verification do |verification|
      check_model(verification)
      check_audio_event(user, verification.audio_event.audio_recording.site, verification.audio_event)
    end

    can [:create, :update], Verification do |verification|
      check_model(verification)
      Access::Core.check_orphan_site!(verification.audio_event.audio_recording.site)

      has_writer_access = Access::Core.can_any?(
        user, :writer, verification.audio_event.audio_recording.site.projects
      )

      # anyone with writer access can create a verification,
      # but only users who created the verifications can update them
      # (and only if they still have access to the project)
      if verification.persisted?
        has_writer_access && verification.creator_id == user&.id
      else
        has_writer_access
      end
    end

    # 1. Are you an owner?
    # 2. Are you a writer?
    # -> 2.1. Are you the creator?
    can [:destroy], Verification do |verification|
      user_level = Access::Core.user_levels(user, verification.audio_event.audio_recording.site.projects)
      next false if user_level.blank? || user_level.compact.blank?

      actual_highest = Access::Core.highest(user_level)
      if actual_highest == :owner
        true
      elsif actual_highest == :writer
        verification.creator_id == user&.id
      else
        false
      end
    end
  end
end
