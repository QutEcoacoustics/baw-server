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

    if user.has_role? :admin
      # admin abilities
      can :manage, :all

    elsif user.has_role?(:user) && user.confirmed?

      # user must have read or write permission on the associated project
      # --------------------------------------

      # project
      # only admin can delete projects
      can [:show], Project do |project|
        AccessLevel.access?(user, project, :reader)
      end
      can [:edit, :update, :update_permissions, :additional_permissions, :update_additional_permissions], Project do |project|
        AccessLevel.access?(user, project, :writer)
      end

      # site
      # only admin can delete sites
      can [:show, :show_shallow], Site do |site|
        AccessLevel.access_any?(user, site.projects, :reader)
      end
      can [:new, :create, :edit, :update], Site do |site|
        AccessLevel.access_any?(user, site.projects, :writer)
      end

      # data set
      can [:show, :show_shallow], Dataset do |dataset|
        AccessLevel.access?(user, dataset.project, :reader)
      end
      can [:new, :create, :edit, :update, :destroy], Dataset do |dataset|
        AccessLevel.access?(user, dataset.project, :writer)
      end

      # job
      can [:show, :create], Job do |job|
        AccessLevel.access?(user, job.dataset.project, :reader)
      end

      # permission
      # :edit and :update are not allowed
      # :show, :create, :delete are only used by json api
      can [:show, :new, :create, :destroy], Permission do |permission|
        AccessLevel.access?(user, permission.project, :writer)
      end

      # audio recording
      can [:show], AudioRecording do |audio_recording|
        AccessLevel.access_any?(user, audio_recording.site.projects, :reader)
      end

      # audio event
      can [:show, :download], AudioEvent do |audio_event|
        AccessLevel.access_any?(user, audio_event.audio_recording.site.projects, :reader)
      end
      can [:create, :edit, :update, :destroy], AudioEvent do |audio_event|
        AccessLevel.access_any?(user, audio_event.audio_recording.site.projects, :writer)
      end

      # audio event comment
      # anyone can view or create comments on reference audio events
      # anyone with read or write or own permissions on the project can create comments
      can [:show, :create], AudioEventComment do |audio_event_comment|
        access_level = AccessLevel.access_any?(user, audio_event_comment.audio_event.audio_recording.site.projects, :reader)
        is_audio_event_ref = audio_event_comment.audio_event.is_reference
        access_level || is_audio_event_ref
      end

      # bookmark
      can [:create], Bookmark do |bookmark|
        AccessLevel.access_any?(user, bookmark.audio_recording.site.projects, :reader)
      end

      # script
      # tag
      # tagging - authorization is done via user and audio_recording and audio_event
      # user

      # --------------------------------------
      # actions users can only take on entries related to them or that they own
      # --------------------------------------

      # users can only view their own comments and projects list (admins can view any user's projects/comments)
      can [:edit, :update, :projects, :audio_event_comments, :bookmarks], User, id: user.id

      # not sure about the ones that work with current_user - won't the check always be true?
      # There's no way to specify any other user id.
      can [:my_account, :modify_preferences], User, id: user.id

      # users can only delete their own comments
      can [:edit, :destroy], AudioEventComment, creator_id: user.id
      can [:edit, :update, :destroy, :show], Bookmark, creator_id: user.id
      can [:edit, :update, :destroy], Job, creator_id: user.id

      # --------------------------------------
      # any confirmed user can access these actions
      # --------------------------------------

      # new is usually available publicly
      # filter permissions are checked as part of filter query

      # any confirmed user can view any other user's profile (read-only) and annotations  (the links may not work due to permissions)
      can [:show, :audio_events], User

      # index permissions are enforced in the controller action
      can [:index, :new, :create, :new_access_request, :submit_access_request, :filter], Project
      can [:index, :filter], Site
      can [:index], Dataset
      can [:index, :new], Job

      # index permission is checked in the controller index action
      can [:index], Permission

      can [:index, :new, :filter], AudioRecording
      # any user can access the library, permissions are checked in the action
      can [:index, :new, :library, :filter], AudioEvent
      # list, filter, update permissions are checked in the action
      can [:index, :new, :filter, :update], AudioEventComment

      can [:index, :new, :filter], Bookmark
      # anyone can create tags
      can [:index, :new, :create, :show], Tag

    elsif user.has_role? :harvester
      # harvester user is used by baw-harvester and baw-workers
      # baw-harvester: :new, :create, :check_uploader, :update_status
      # baw-workers: :update
      can [:new, :create, :check_uploader, :update_status, :update], AudioRecording

    end
  end
end