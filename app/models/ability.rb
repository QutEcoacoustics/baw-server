class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here.
    user ||= User.new # guest user (not logged in)

    if user.has_role? :admin
      # admin abilities
      can :manage, :all

    elsif user.has_role?(:user) && user.confirmed?
      #user abilities
      can [:show], User
      can [:update], User, id: user.id
      can [:my_account, :modify_preferences], User, user_id: user.id
      can [:index, :create, :new_access_request, :submit_access_request], Project
      can [:read, :update, :update_permissions], Project do |project|
        user.can_write?(project)
      end
      can [:read], Project do |project|
        user.can_read?(project)
      end
      can [:manage], Permission do |permission|
        user.can_write?(permission.project)
      end
      can [:manage], Site do |site|
        user.can_write_any?(site.projects)
      end
      can [:read], Site do |site|
        user.has_permission_any?(site.projects)
      end
      can [:manage], Dataset do |dataset|
        user.can_write?(dataset.project)
      end
      can [:read], Dataset do |dataset|
        user.has_permission?(dataset.project)
      end
      can [:manage], Job do |job|
        user.can_write?(job.dataset.project)
      end
      can [:read], Job do |job|
        user.has_permission?(job.dataset.project)
      end
      can [:show, :index], AudioRecording do |audio_recording|
        user.has_permission_any?(audio_recording.site.projects)
      end
      can [:manage], AudioEvent do |audio_event|
        user.can_write_any?(audio_event.audio_recording.site.projects)
      end
      can [:read], AudioEvent do |audio_event|
        user.has_permission_any?(audio_event.audio_recording.site.projects)
      end
      can [:manage], Tag
      can [:manage], Bookmark, creator_id: user.id
      can [:read], Bookmark
      can [:library, :library_paged], AudioEvent
      #can [:audio, :spectrogram], Media if user.has_permission_any?(media.audio_recording.site.projects)
      can [:manage], AudioEventComment do |audio_event_comment|
        user.can_write_any?(audio_event_comment.audio_event.audio_recording.site.projects)
      end
      can [:manage], AudioEventComment do |audio_event_comment|
        user.has_permission_any?(audio_event_comment.audio_event.audio_recording.site.projects)
      end

    elsif user.has_role? :harvester
      can [:manage, :check_uploader], AudioRecording

    end
  end
end