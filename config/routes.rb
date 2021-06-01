# frozen_string_literal: true

require 'resque/server'

Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # api-docs
  # ======================
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # User and Devise routes
  # ======================

  # standard devise for website authentication
  # NOTE: the sign in route is used by baw-workers to log in, ensure any changes are reflected in baw-workers.
  devise_for :users,
             path: :my_account,
             controllers: { sessions: 'users/sessions', registrations: 'users/registrations' }

  # devise for RESTful API Authentication, see sessions_controller.rb
  devise_for :users,
             controllers: { sessions: 'sessions' },
             as: :security,
             path: :security,
             defaults: { format: 'json' },
             only: [],
             skip_helpers: true

  # provide a way to get the current user's auth token
  # will most likely use cookies, since there is no point using a token to get the token...
  # the devise_scope is needed due to
  # https://github.com/plataformatec/devise/issues/2840#issuecomment-43262839
  devise_scope :security_user do
    # no index
    post '/security' => 'sessions#create', defaults: { format: 'json' }
    get '/security/new' => 'sessions#new', defaults: { format: 'json' }
    get '/security/user' => 'sessions#show', defaults: { format: 'json' } # 'user' represents the current user id
    # no edit view
    # no update
    delete '/security' => 'sessions#destroy', defaults: { format: 'json' }
  end

  # when a user goes to my account, render user_account/show view for that user
  get '/my_account/' => 'user_accounts#my_account'

  # for updating only preferences for only the currently logged in user
  put '/my_account/prefs/' => 'user_accounts#modify_preferences'

  # TODO: this will be changed from :user_accounts to :users at some point
  # user accounts filter, placed above to not conflict with /user_accounts/:id
  match 'user_accounts/filter' => 'user_accounts#filter', via: [:get, :post], defaults: { format: 'json' }

  # user list and user profile
  resources :user_accounts, only: [:index, :show, :edit, :update], constraints: { id: /[0-9]+/ } do
    member do
      get 'projects'
      get 'sites'
      get 'bookmarks'
      get 'audio_events'
      get 'audio_event_comments'
      get 'saved_searches'
      get 'analysis_jobs'
    end
  end

  # Resource Routes
  # ===============

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'bookmarks/filter' => 'bookmarks#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :bookmarks, except: [:edit]

  # routes used by workers:
  # login: /security/sign_in
  # audio_recording_update: /audio_recordings/:id

  # routes used by harvester:
  # login: /security
  # audio_recording: /audio_recordings/:id
  # audio_recording_create: /projects/:project_id/sites/:site_id/audio_recordings
  # audio_recording_uploader: /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id
  # audio_recording_update_status: /audio_recordings/:id/update_status

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'projects/filter' => 'projects#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'projects/:project_id/regions/filter' => 'regions#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'projects/:project_id/sites/filter' => 'sites#filter', via: [:get, :post], defaults: { format: 'json' }

  # routes for projects and nested resources
  resources :projects do
    member do
      get 'edit_sites'
      put 'update_sites'
      patch 'update_sites'
    end
    collection do
      get 'new_access_request'
      post 'submit_access_request'
    end
    # project permissions
    resources :permissions, only: [:index]
    resources :permissions, except: [:edit, :update, :index], defaults: { format: 'json' }
    # HTML project site item
    resources :sites, except: [:index] do
      member do
        get :upload_instructions
        get 'harvest' => 'sites#harvest'
      end
      # API project site recording check_uploader
      resources :audio_recordings, only: [:create, :new], defaults: { format: 'json' } do
        collection do
          get 'check_uploader/:uploader_id', defaults: { format: 'json' }, action: :check_uploader
        end
      end
    end
    # API project sites list
    resources :sites, only: [:index], defaults: { format: 'json' }

    # API only: regions
    resources :regions, except: [:edit], defaults: { format: 'json' }
  end

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'analysis_jobs/filter' => 'analysis_jobs#filter',
        via: [:get, :post], defaults: { format: 'json' }
  match 'analysis_jobs/:analysis_job_id/audio_recordings/filter' => 'analysis_jobs_items#filter',
        via: [:get, :post], defaults: { format: 'json' }, as: :analysis_job_analysis_jobs_items_filter
  match 'saved_searches/filter' => 'saved_searches#filter',
        via: [:get, :post], defaults: { format: 'json' }

  # route for AnalysisJobsItems and results
  match 'analysis_jobs/:analysis_job_id/results/' => 'analysis_jobs_results#index',
        defaults: { format: 'json' }, as: :analysis_jobs_results_index, via: [:get, :head], format: false, action: 'index'
  match 'analysis_jobs/:analysis_job_id/results/:audio_recording_id(/*results_path)' => 'analysis_jobs_results#show',
        defaults: { format: 'json' }, as: :analysis_jobs_results_show, via: [:get, :head], format: false, action: 'show'

  # API only for analysis_jobs, analysis_jobs_items and saved_searches
  resources :analysis_jobs, except: [:edit], defaults: { format: 'json' } do
    resources 'audio_recordings', controller: 'analysis_jobs_items', only: [:show, :index, :update],
                                  defaults: { format: 'json' }, param: :audio_recording_id
  end
  resources :saved_searches, except: [:edit, :update], defaults: { format: 'json' }

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'audio_recordings/filter' => 'audio_recordings#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'audio_events/filter' => 'audio_events#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'taggings/filter' => 'taggings#filter', via: [:get, :post], defaults: { format: 'json' }

  # API audio recording item
  resources :audio_recordings, only: [:index, :show, :new, :update], defaults: { format: 'json' } do
    match 'media.:format' => 'media#show', defaults: { format: 'json' }, as: :media, via: [:get, :head]
    scope defaults: { format: false } do
      match 'original' => 'media#original', as: :media_original, via: [:get, :head]
    end
    resources :audio_events, except: [:edit], defaults: { format: 'json' } do
      collection do
        get 'download', defaults: { format: 'csv' }
      end
      resources :tags, only: [:index], defaults: { format: 'json' }
      resources :taggings, except: [:edit], defaults: { format: 'json' }
    end
  end

  # API update status for audio_recording item, separate so it has :id and not :audio_recording_id
  resources :audio_recordings, only: [], defaults: { format: 'json' }, shallow: true do
    member do
      put 'update_status' # for when harvester has moved a file to the correct location
    end
  end

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'tags/filter' => 'tags#filter', via: [:get, :post], defaults: { format: 'json' }

  # API tags
  resources :tags, only: [:index, :show, :create, :new], defaults: { format: 'json' }

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'audio_event_comments/filter' => 'audio_event_comments#filter', via: [:get, :post], defaults: { format: 'json' }

  # API audio_event create
  resources :audio_events, only: [], defaults: { format: 'json' } do
    resources :audio_event_comments, except: [:edit], defaults: { format: 'json' }, path: :comments, as: :comments
  end

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match '/scripts/filter' => 'scripts#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :scripts, only: [:index, :show], defaults: { format: 'json' }

  # taggings made by a user
  get '/user_accounts/:user_id/taggings' => 'taggings#user_index', as: :user_taggings, defaults: { format: 'json' }

  # audio event csv download routes
  get '/projects/:project_id/audio_events/download' => 'audio_events#download',
      defaults: { format: 'csv' }, as: :download_project_audio_events
  get '/projects/:project_id/sites/:site_id/audio_events/download' => 'audio_events#download',
      defaults: { format: 'csv' }, as: :download_site_audio_events
  get '/user_accounts/:user_id/audio_events/download' => 'audio_events#download',
      defaults: { format: 'csv' }, as: :download_user_audio_events

  # placed above related resource so it does not conflict with (resource)/:id => (resource)#show
  match 'sites/filter' => 'sites#filter', via: [:get, :post], defaults: { format: 'json' }

  # path for orphaned sites
  get 'sites/orphans' => 'sites#orphans'
  match 'sites/orphans/filter' => 'sites#orphans', via: [:get, :post], defaults: { format: 'json' }

  # shallow path to sites

  resources :sites, except: [:edit], defaults: { format: 'json' }, as: 'shallow_site'

  match 'regions/filter' => 'regions#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :regions, except: [:edit], defaults: { format: 'json' }, as: 'shallow_region'

  match 'datasets/:dataset_id/progress_events/audio_recordings/:audio_recording_id/start/:start_time_seconds/end/:end_time_seconds' =>
    'progress_events#create_by_dataset_item_params',
        :constraints => {
          dataset_id: /(\d+|default)/,
          audio_recording_id: /\d+/,
          start_time_seconds: /\d+(\.\d+)?/,
          end_time_seconds: /\d+(\.\d+)?/
        },
        via: [:post],
        defaults: { format: 'json' }

  # datasets, dataset_items
  match 'datasets/filter' => 'datasets#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'dataset_items/filter' => 'dataset_items#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'datasets/:dataset_id/dataset_items/filter' => 'dataset_items#filter',
        via: [:get, :post],
        defaults: { format: 'json' }
  match 'datasets/:dataset_id/dataset_items/next_for_me' => 'dataset_items#next_for_me',
        via: [:get],
        defaults: { format: 'json' }
  resources :datasets, except: :destroy, defaults: { format: 'json' } do
    resources :items, controller: 'dataset_items', defaults: { format: 'json' }
  end

  # studies, questions, responses
  put 'responses/:id', to: 'errors#method_not_allowed_error'
  put '/studies/:study_id/responses/:id', to: 'errors#method_not_allowed'
  match 'studies/filter' => 'studies#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'questions/filter' => 'questions#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'responses/filter' => 'responses#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :studies, defaults: { format: 'json' }
  resources :questions, defaults: { format: 'json' }
  resources :responses, except: :update, defaults: { format: 'json' }
  get '/studies/:study_id/questions' => 'questions#index', defaults: { format: 'json' }
  get '/studies/:study_id/responses' => 'responses#index', defaults: { format: 'json' }
  post '/studies/:study_id/questions/:question_id/responses' => 'responses#create', defaults: { format: 'json' }

  # progress events
  match 'progress_events/filter' => 'progress_events#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :progress_events, defaults: { format: 'json' }

  # route to the home page of site
  root to: 'public#index'

  # site status API
  get '/status/' => 'public#status', defaults: { format: 'json' }
  get '/website_status/' => 'public#website_status'

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
  get '/data_upload' => 'public#data_upload'
  get '/credits' => 'public#credits'

  # resque front end - admin only
  authenticate :user, ->(u) { Access::Core.is_admin?(u) } do
    # add stats tab to web interface from resque-job-stats
    require 'resque-job-stats/server'
    # adds Statuses tab to web interface from resque-status
    require "#{Rails.root}/lib/gems/resque-status/lib/resque/status_server"
    # enable resque web interface
    mount Resque::Server.new, at: '/job_queue_status'
  end

  # for admin-only section of site
  namespace :admin do
    get '/' => 'home#index', as: :dashboard
    resources :tags, :tag_groups
    resources :audio_recordings, :analysis_jobs, only: [:index, :show]

    resources :scripts, except: [:update] do
      member do
        post :update
      end
    end
  end

  # provide access to API documentation
  # NOTE: disabled because broken
  #mount Raddocs::App => '/doc'

  # enable CORS preflight requests
  match '*requested_route', to: 'public#cors_preflight', via: :options

  # exceptions testing route - only available in test env
  if ENV['RAILS_ENV'] == 'test'
    # via: :all seems to not work any more >:(
    match '/test_exceptions', to: 'errors#test_exceptions', via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]
  end

  comfy_route_cms_admin(path: '/admin/cms')
  # Ensure that this route is defined last
  comfy_route :cms, path: '/cms'

  # routes directly to error pages
  match '/errors/:name', to: 'errors#show', via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]

  # for error pages - must be last
  match '*requested_route', to: 'errors#route_error', via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]
end
