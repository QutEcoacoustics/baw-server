require 'resque/server'

AWB::Application.routes.draw do

  # See how all your routes lay out with "rake routes"

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # standard devise for website authentication
  devise_for :users, path: :my_account
  resources :users, controller: :user_accounts

  resources :user_accounts do
    resources :permissions
    resources :bookmarks, only: [:index], defaults: {format: 'json'}
    member do
      get 'projects'
    end
  end

  # routes for projects and nested resources
  resources :projects do
    member do
      post 'update_permissions'
    end
    collection do
      get 'new_access_request'
      post 'submit_access_request'
    end
    resources :permissions, except: [:show]
    resources :permissions, only: [:show], defaults: {format: 'json'}
    resources :sites, except: [:index] do
      member do
        get :upload_instructions
        get 'harvest' => 'sites#harvest', defaults: {format: 'yml'}, constraints: {format: /(yml)/}
      end
      resources :audio_recordings, only: [:index, :new, :create, :show], defaults: {format: 'json'} do
        collection do
          get 'check_uploader/:uploader_id', defaults: {format: 'json'}, action: :check_uploader
        end
        get 'media.:format' => 'media#show', defaults: {format: 'json'}, as: :media
        resources :audio_events, defaults: {format: 'json'} do
          resources :tags, only: [:index], defaults: {format: 'json'}
          resources :taggings, defaults: {format: 'json'}
        end
      end
    end
    resources :sites, only: [:index], defaults: {format: 'json'}
    resources :datasets, except: [:index] do
      resources :jobs, only: [:show]
      resources :jobs, only: [:index], defaults: {format: 'json'}
    end
    resources :datasets, only: [:index], defaults: {format: 'json'}
    resources :jobs, except: [:index, :show]
    resources :jobs, only: [:index], defaults: {format: 'json'}
  end

  # allow shallow paths to audio_recordings
  # TODO: cleanup unneccessary paths
  resources :audio_recordings, only: [:show], defaults: {format: 'json'} do
    get 'media.:format' => 'media#show', defaults: {format: 'json'}, as: :media
    resources :audio_events, defaults: {format: 'json'} do
      collection do
        get 'download', defaults: {format: 'csv'}
      end
      resources :tags, only: [:index], defaults: {format: 'json'}
      resources :taggings, defaults: {format: 'json'}
    end
  end

  # routes for audio recordings and bookmarks within particular recordings
  resources :audio_recordings, only: [], defaults: {format: 'json'}, shallow: true do
    member do
      put 'update_status' # for when harvester has moved a file to the correct location
    end
    resources :bookmarks, defaults: {format: 'json'}
  end
  resources :tags, only: [:index, :show, :create, :new], defaults: {format: 'json'}
  resources :audio_events, only: [:new], defaults: {format: 'json'} do
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

  # shallow path to sites
  get '/sites/:id' => 'sites#show_shallow', defaults: {format: 'json'}

  # devise for RESTful API Authentication, see Api/sessions_controller.rb
  devise_for :users, controllers: {sessions: 'sessions'},
             as: :security, path: :security, defaults: {format: 'json'},
             only: [:sessions], skip_helpers: true

  # route to the home page of site
  root to: 'public#index'

  # when a user goes to my account, render user_account/show view for that user
  get '/my_account/' => 'user_accounts#my_account'

  # for updating only preferences for only the currently logged in user
  put '/my_account/prefs/' => 'user_accounts#modify_preferences'

  # site status API
  get '/status/' => 'public#status', defaults: {format: 'json'}
  get '/website_status/' => 'public#website_status'
  get '/audio_recording_catalogue/' => 'public#audio_recording_catalogue'

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
    mount Resque::Server.new, at: '/job_queue_status'
  end

  # provide access to API documentation
  mount Raddocs::App => '/doc'

  # for error pages (add via: :all for rails 4)
  match '*requested_route', to: 'errors#routing'

end
