class Ability
  include CanCan::Ability

  def initialize(user)

    # Define abilities for the passed in user here.

    # clear all aliased actions - these mappings are removed:
    #   alias_action :index, :show, :to => :read
    #   alias_action :new, :to => :create
    #   alias_action :edit, :to => :update
    clear_aliased_actions
    #                                               | Can be used in |
    # HTTP Verb   | Path                | Action    | a block?       | Purpose
    #-------------|---------------------|-----------|----------------------------------------
    # GET         | /projects           | :index    | NO             | display a list of all projects
    # GET         | /projects/new       | :new      | NO             | return an HTML form/json properties for creating a new project
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
    # This is mainly relevant for :index, :create, and :new.
    # since they do no have an instance of the model.

    # WARNING: :manage represents ANY action on the object.
    # DO NOT use :manage except for the admin user

    # WARNING: instance variable in controller index action will not be set if using a block for can definitions
    # because there is no way to determine which records to fetch from the database.

    user ||= User.new # guest user (not logged in)

    # for api security endpoints
    can [:show, :destroy], :api_security if user.confirmed?

    if Access::Check.is_admin?(user)
      # admin can access any action on any controller
      can :manage, :all

    elsif Access::Check.is_standard_user?(user)

      # FYI
      # ----------------------------
      #  - index and filter permissions are checked as part of filter query
      #  - new is usually available publicly
      #  - not sure about the ones that work with current_user (user):
      #    won't the check always be true? Since there's no way to specify any other user id.

      # available models:
      # Project, Permission, Site, AudioRecording,
      # AudioEvent, AudioEventComment, Bookmark,
      # AnalysisJob, SavedSearch, Script, Tag, Tagging, User


      # Project
      # ----------------------------
      # only admin can :destroy, :edit_sites, :update_sites
      # :update_permissions, :update_sites are html-only

      # must have read permission or higher to view project
      can [:show], Project do |project|
        Access::Check.can?(user, :reader, project)
      end

      # must have write permission or higher to edit, update, update_permission
      can [:edit, :update, :update_permissions], Project do |project|
        Access::Check.can?(user, :writer, project)
      end

      # actions any logged in user can access
      can [:index, :new, :create, :new_access_request, :submit_access_request, :filter], Project

      # Permission
      # ----------------------------
      # :show, :create, :delete are only used by json api
      # :edit and :update are done via project instead

      can [:show, :new, :create, :destroy], Permission do |permission|
        Access::Check.can?(user, :writer, permission.project)
      end

      # actions any logged in user can access
      can [:index, :filter], Permission

      # Site
      # ----------------------------
      # only admin can :destroy, :upload_instructions, :harvest, :orphans

      # must have read permission or higher to view site
      can [:show, :show_shallow], Site do |site|
        # can't add .includes here - it breaks when validating projects due to ActiveRecord::AssociationRelation
        Access::Check.can_any?(user, :reader, site.projects)
      end

      # must have write permission or higher to new, create, edit, update
      can [:new, :create, :edit, :update], Site do |site|
        # can't add .includes here - it breaks when validating projects due to ActiveRecord::AssociationRelation
        # .all would have worked. I tried .where(nil), that didn't work either :/
        # https://github.com/rails/rails/issues/12756
        # https://github.com/plataformatec/has_scope/issues/41
        Access::Check.can_any?(user, :writer, site.projects)
      end

      # actions any logged in user can access
      can [:index, :filter], Site

      # AudioRecording
      # ----------------------------
      # See permissions for harvester at end of this file
      # Only admin and harvester can :create, :check_uploader, :update_status, :update
      # permissions are also checked in actions

      # must have read permission or higher to view audio recording
      can [:show], AudioRecording do |audio_recording|
        Access::Check.can_any?(user, :reader, audio_recording.site.projects)
      end

      # actions any logged in user can access
      can [:index, :new, :filter], AudioRecording

      # AudioEvent
      # ----------------------------

      # must have read permission or higher to view or download audio event
      can [:show, :download], AudioEvent do |audio_event|
        Access::Check.can_any?(user, :reader, audio_event.audio_recording.site.projects)
      end

      # must have write permission or higher to create, update, destroy
      can [:create, :update, :destroy], AudioEvent do |audio_event|
        Access::Check.can_any?(user, :writer, audio_event.audio_recording.site.projects)
      end

      # actions any logged in user can access
      can [:index, :new, :filter], AudioEvent

      # AudioEventComment
      # ----------------------------

      # logged in users
      # with read permission or higher on the project
      # or if the audio event is a reference
      # can view or create comments
      # can also update flag, any other attribute is restricted in action to creator
      can [:show, :create, :update], AudioEventComment do |audio_event_comment|
        is_ref = audio_event_comment.audio_event.is_reference
        projects = audio_event_comment.audio_event.audio_recording.site.projects
        Access::Check.can_any?(user, :reader, projects) || is_ref
      end

      # only creator can update or destroy their own comments
      can [:destroy], AudioEventComment, creator_id: user.id

      # actions any logged in user can access
      can [:index, :new, :filter], AudioEventComment

      # Bookmark
      # ----------------------------

      # must have read permission or higher on project to create bookmark
      can [:create], Bookmark do |bookmark|
        Access::Check.can_any?(user, :reader, bookmark.audio_recording.site.projects)
      end

      # only creator can update, destroy, show their own bookmarks
      can [:update, :destroy, :show], Bookmark, creator_id: user.id

      # actions any logged in user can access
      can [:index, :new, :filter], Bookmark

      # AnalysisJob
      # ----------------------------

      # must have read permission or higher on any saved_search projects to create analysis job
      can [:show, :create], AnalysisJob do |analysis_job|
        Access::Check.can_any?(user, :reader, analysis_job.saved_search.projects)
      end

      # only creator can update, destroy their own analysis jobs
      can [:update, :destroy], AnalysisJob, creator_id: user.id

      # actions any logged in user can access
      can [:index, :new, :filter], AnalysisJob

      # SavedSearch
      # ----------------------------
      # cannot be updated

      # must have read permission or higher on any projects to create saved search
      can [:show, :create], SavedSearch do |saved_search|
        Access::Check.can_any?(user, :reader, saved_search.projects)
      end

      # only creator can destroy their own saved searches
      can [:destroy], SavedSearch, creator_id: user.id

      # actions any logged in user can access
      can [:index, :new, :filter], SavedSearch

      # Script
      # ----------------------------
      # only admin can do anything with Script

      # Tag
      # ----------------------------
      # cannot be updated
      # tag management controller is admin only (checked in before_action)

      # actions any logged in user can access
      can [:index, :new, :create, :show, :filter], Tag

      # Tagging
      # ----------------------------
      # uses permissions from other models

      # User
      # ----------------------------
      # admin only: :index, :edit, :update
      # :edit and :update are the Admin interface for editing any user
      # normal users edit their profile using devise/registrations#edit

      # any confirmed user can view any other user's profile (read-only) and annotations  (the links may not work due to permissions)
      can [:show, :audio_events, :filter], User

      # users can only view their own projects, comments, bookmarks (admins can view any user's projects/comments/bookmarks)

      can [:projects, :audio_event_comments, :bookmarks], User, id: user.id

      # users get their own account and preferences from these actions
      can [:my_account, :modify_preferences], User, id: user.id

    elsif Access::Check.is_harvester?(user)
      # actions used for harvesting. See baw-workers.
      can [:new, :create, :check_uploader, :update_status, :update], AudioRecording

    end
  end
end