class Ability
  include CanCan::Ability

  def initialize(user)

    # Define abilities for the passed in user here.

    # clear all aliased actions - these mappings are removed:
    #   alias_action :index, :show, :to => :read
    #   alias_action :new, :to => :create
    #   alias_action :edit, :to => :update
    clear_aliased_actions

    # HTTP Verb   | Path                | Action    | Purpose
    #-------------|---------------------|-----------|----------------------------------------
    # GET         | /projects           | :index    | display a list of all projects
    # GET         | /projects/new       | :new      | return an HTML form/json properties for creating a new project
    # POST        | /projects           | :create   | create a new project
    # GET         | /projects/:id       | :show     | display a specific project
    # GET         | /projects/:id/edit  | :edit     | return an HTML form for editing a project (not relevant to json API)
    # PUT         | /projects/:id       | :update   | update a specific project
    # DELETE      | /projects/:id       | :destroy  | delete a specific project


    # WARNING: If a block or hash of conditions exist they will be ignored
    # when checking on a class, and it will return true.
    # Think of it as asking "can the current user read *a* project?" when using a class,
    # and "can the current user read *this* project?" when checking an instance.
    # This is mainly relevant for :index, :create, and :new.
    # since they do no have an instance of the model.

    # WARNING: :manage represents ANY action on the object.

    # WARNING: instance variable in controller index action will not be set if using a block for can definitions
    # because there is no way to determine which records to fetch from the database.

    user ||= User.new # guest user (not logged in)

    if user.has_role? :admin
      # admin abilities
      can :manage, :all

    elsif user.has_role?(:user) && user.confirmed?

      # user must have read or write permission on the associated project
      # --------------------------------------
      can [:show], Project do |project|
        user.has_permission?(project)
      end
      can [:edit, :update, :update_permissions], Project do |project|
        user.can_write?(project)
      end
      can [:manage], Permission do |permission|
        user.can_write?(permission.project)
      end
      can [:manage], Site do |site|
        user.can_write_any?(site.projects)
      end
      can [:index, :show], Site do |site|
        user.has_permission_any?(site.projects)
      end
      can [:manage], Dataset do |dataset|
        user.can_write?(dataset.project)
      end
      can [:index, :show, :show_shallow], Dataset do |dataset|
        user.has_permission?(dataset.project)
      end
      can [:manage], Job do |job|
        user.can_write?(job.dataset.project)
      end
      can [:index, :show], Job do |job|
        user.has_permission?(job.dataset.project)
      end
      can [:index, :show], AudioRecording do |audio_recording|
        user.has_permission_any?(audio_recording.site.projects)
      end
      can [:manage], AudioEvent do |audio_event|
        user.can_write_any?(audio_event.audio_recording.site.projects)
      end
      can [:show, :download], AudioEvent do |audio_event|
        user.has_permission_any?(audio_event.audio_recording.site.projects)
      end
      can [:show], Bookmark do |bookmark|
        user.has_permission_any?(bookmark.audio_recording.site.projects)
      end
      can [:show], AudioEventComment do |audio_event_comment|
        user.has_permission_any?(audio_event_comment.audio_event.audio_recording.site.projects)
      end

      # --------------------------------------
      # actions users can only take on entries related to them or that they own
      # --------------------------------------

      # users can only view their own comments and projects list (admins can view any user's projects/comments)
      can [:edit, :update, :projects, :audio_event_comments], User, id: user.id

      # not sure about the ones that work with current_user - won't the check always be true?
      # There's no way to specify any other user id.
      can [:my_account, :modify_preferences], User, user_id: user.id

      # users can only change or delete their own bookmarks and comments
      can [:edit, :update, :destroy], AudioEventComment, creator_id: user.id
      can [:edit, :update, :destroy], Bookmark, creator_id: user.id

      # --------------------------------------
      # any confirmed user can access these actions
      # --------------------------------------

      # view a user's profile (read-only)
      # any confirmed user can view any other user's annotations and bookmarks (the links may not work due to permissions)
      can [:show, :bookmarks, :audio_events], User

      # projects: list, create, request access
      can [:index, :new, :create, :new_access_request, :submit_access_request], Project

      # Permissions: list, create
      can [:index, :new], Permission

      # Tags: list, create
      can [:index, :show, :new, :create], Tag

      # Bookmarks: list, create, filter (permissions are checked in the action)
      can [:index, :new, :create, :filter], Bookmark

      # get the audio events library (permissions are checked in the action)
      can [:index, :new, :create, :library, :library_paged], AudioEvent

      # Audio Recordings: filter (permissions are checked in the action)
      can [:filter, :new], AudioRecording

      # Audio Event Comment: list, create
      can [:index, :new, :create], AudioEventComment

    elsif user.has_role? :harvester
      can [:new, :create, :check_uploader, :update_status], AudioRecording

    end
  end
end