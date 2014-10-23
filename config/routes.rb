require 'resque/server'

AWB::Application.routes.draw do

  # See how all your routes lay out with "rake routes"

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # User and Devise routes
  # ======================

  # standard devise for website authentication
  devise_for :users, path: :my_account

  # devise for RESTful API Authentication, see Api/sessions_controller.rb
  # /security/sign_in is used by the harvester, do not change!
  devise_for :users,
             controllers: {sessions: 'sessions'},
             as: :security,
             path: :security,
             defaults: {format: 'json'},
             only: [:sessions],
             skip_helpers: true

  # when a user goes to my account, render user_account/show view for that user
  get '/my_account/' => 'user_accounts#my_account'

  # for updating only preferences for only the currently logged in user
  put '/my_account/prefs/' => 'user_accounts#modify_preferences'

  #TODO: this will be changed from :user_accounts to :users at some point
  # user list and user profile
  resources :user_accounts, only: [:index, :show, :edit, :update], constraints: {id: /[0-9]+/} do
    member do
      get 'projects'
      get 'bookmarks'
      get 'audio_events'
      get 'audio_event_comments'
    end
  end

  # Resource Routes
  # ===============

  match 'bookmarks/filter' => 'bookmarks#filter', via: [:get, :post], defaults: {format: 'json'}
  resources :bookmarks, except: [:edit]

  # routes used by workers:
  # login: /security/sign_in
  # audio_recording_update: /audio_recordings/:id

  # routes used by harvester:
  # endpoint_login: /security/sign_in
  # endpoint_create: /projects/:project_id/sites/:site_id/audio_recordings
  # endpoint_check_uploader: /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id
  # endpoint_update_status: /audio_recordings/:id/update_status

  # endpoints used by client:
  # routes: {
  #     project: "/projects/{projectId}",
  #     site: {
  #         flattened: "/sites/{siteId}",
  #         nested: "/projects/{projectId}/sites/{siteId}"
  #     },
  #     audioRecording: {
  #         listShort: "/audio_recordings/{recordingId}",
  #         show: "/audio_recordings/{recordingId}",
  #         list: "/audio_recordings/"
  #     },
  #     audioEvent: {
  #         list: "/audio_recordings/{recordingId}/audio_events",
  #         show: "/audio_recordings/{recordingId}/audio_events/{audioEventId}",
  #         csv: "/audio_recordings/{recordingId}/audio_events/download.{format}",
  #         library: "/audio_events/library/paged"
  #     },
  #     tagging: {
  #         list: "/audio_recordings/{recordingId}/audio_events/{audioEventId}/taggings",
  #         show: "/audio_recordings/{recordingId}/audio_events/{audioEventId}/taggings/{taggingId}"
  #     },
  #     tag: {
  #         list: '/tags/',
  #         show: '/tags/{tagId}'
  #     },
  #     media: {
  #         show: "/audio_recordings/{recordingId}/media.{format}"
  #     },
  #     security: {
  #         ping: "/security/sign_in",
  #         signIn: "/my_account/sign_in"
  #     },
  #     user: {
  #         profile: "/my_account",
  #         settings: "/my_account/prefs"
  #     }
  # },
  #     links: {
  #     projects: '/projects',
  #     home: '/',
  #     project: '/projects/{projectId}',
  #     site: '/projects/{projectId}/sites/{siteId}',
  #     userAccounts: '/user_accounts/{userId}'
  # }

  # routes for projects and nested resources
  resources :projects do
    member do
      post 'update_permissions'
    end
    collection do
      get 'new_access_request'
      post 'submit_access_request'
    end
    # HTML project permissions list
    resources :permissions, only: [:index]
    # API project permission item
    resources :permissions, except: [:index, :edit, :update], defaults: {format: 'json'}
    # HTML project site item
    resources :sites, except: [:index] do
      member do
        get :upload_instructions
        get 'harvest' => 'sites#harvest', defaults: {format: 'yml'}, constraints: {format: /(yml)/}
      end
      # API project site recording check_uploader
      resources :audio_recordings, only: [:create, :new], defaults: {format: 'json'} do
        collection do
          get 'check_uploader/:uploader_id', defaults: {format: 'json'}, action: :check_uploader
        end
      end
    end
    # API project sites list

    resources :sites, only: [:index], defaults: {format: 'json'}
    resources :datasets, except: [:index] do
      resources :jobs, only: [:show]
      resources :jobs, only: [:index], defaults: {format: 'json'}
    end
    resources :datasets, only: [:index], defaults: {format: 'json'}
    resources :jobs, except: [:index, :show]
    resources :jobs, only: [:index], defaults: {format: 'json'}
  end

  # placed here so it does not conflict with audio_recordings/:id => audio_recordings#show
  match 'audio_recordings/filter' => 'audio_recordings#filter', via: [:get, :post], defaults: {format: 'json'}

  # API audio recording item
  resources :audio_recordings, only: [:index, :show, :new, :update], defaults: {format: 'json'} do
    get 'media.:format' => 'media#show', defaults: {format: 'json'}, as: :media
    resources :audio_events, except: [:edit], defaults: {format: 'json'} do
      collection do
        get 'download', defaults: {format: 'csv'}
      end
      resources :tags, only: [:index], defaults: {format: 'json'}
      resources :taggings, except: [:edit], defaults: {format: 'json'}
    end
  end

  # API update status for audio_recording item, separate so it has :id and not :audio_recording_id
  resources :audio_recordings, only: [], defaults: {format: 'json'}, shallow: true do
    member do
      put 'update_status' # for when harvester has moved a file to the correct location
    end
  end

  # API tags
  resources :tags, only: [:index, :show, :create, :new], defaults: {format: 'json'}

  # API audio_event create
  resources :audio_events, only: [], defaults: {format: 'json'} do
    match 'comments/filter' => 'audio_event_comments#filter', via: [:get, :post], defaults: {format: 'json'}
    resources :audio_event_comments, except: [:edit], defaults: {format: 'json'}, path: :comments, as: :comments
    collection do
      get 'library'
      get 'library/paged' => 'audio_events#library_paged', as: :library_paged
    end
  end

  # custom routes for scripts
  resources :scripts, except: [:update, :destroy] do
    member do
      get 'versions' => 'scripts#versions', as: :versions
      get 'versions/:version_id' => 'scripts#version', as: :version
      post :update
    end
  end

  # taggings made by a user
  get '/taggings/user/:user_id/tags' => 'taggings#user_index', as: :user_taggings, defaults: {format: 'json'}

  # audio event csv download routes
  get '/projects/:project_id/audio_events/download' => 'audio_events#download', defaults: {format: 'csv'}, as: :download_project_audio_events
  get '/projects/:project_id/sites/:site_id/audio_events/download' => 'audio_events#download', defaults: {format: 'csv'}, as: :download_site_audio_events

  # placed here so it does not conflict with sites/:id => sites#show
  match 'sites/filter' => 'sites#filter', via: [:get, :post], defaults: {format: 'json'}

  # shallow path to sites
  get '/sites/:id' => 'sites#show_shallow', defaults: {format: 'json'}

  # route to the home page of site
  root to: 'public#index'

  # site status API
  get '/status/' => 'public#status', defaults: {format: 'json'}
  get '/website_status/' => 'public#website_status'
  get '/audio_recording_catalogue/' => 'public#audio_recording_catalogue'

  # exceptions testing route - only available in test env
  if ENV['RAILS_ENV'] == 'test'
    get '/test_exceptions' => 'public#test_exceptions'
  end

  # feedback and contact forms
  get '/contact_us' => 'public#new_contact_us'
  post '/contact_us' => 'public#create_contact_us'
  get '/bug_report' => 'public#new_bug_report'
  post '/bug_report' => 'public#create_bug_report'
  get '/data_request' => 'public#new_data_request'
  post '/data_request' => 'public#create_data_request'

  # static info pages
  get '/disclaimers' => 'public#disclaimers'
  get '/ethics_statement' => 'public#ethics_statement'
  get '/credits' => 'public#credits'

  # resque front end
  authenticate :user, lambda { |u| !u.blank? && u.has_role?(:admin) } do
    # add stats tab to web interface from resque-job-stats
    require 'resque-job-stats/server'
    # adds Statuses tab to web interface from resque-status
    require 'resque/status_server'
    # enable resque web interface
    mount Resque::Server.new, at: '/job_queue_status'
  end

  # provide access to API documentation
  mount Raddocs::App => '/doc'

  # for error pages (add via: :all for rails 4)
  match '*requested_route', to: 'errors#route_error'

end
