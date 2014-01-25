AWB::Application.routes.draw do

  # See how all your routes lay out with "rake routes"

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # standard devise for website authentication
  devise_for :users, :path => :my_account

  resources :user_accounts do
    resources :permissions
    resources :bookmarks, :only => [:index], :defaults => { :format => 'json' }
  end

  # routes for projects and nested resources
  resources :projects do
    member do
      post 'update_permissions'
    end
    resources :permissions, :except => [:show]
    resources :permissions, :only => [:show], :defaults => { :format => 'json' }
    resources :sites, :except => [:index] do
      member do
        get 'upload_instructions'
        get 'harvest' => 'sites#harvest', :defaults => { :format => 'yml' }, :constraints => {:format => /(yml)/}
      end
      resources :audio_recordings, :only => [:index, :new, :create, :show], :defaults => { :format => 'json' } do
        collection do
          get 'check_uploader', :defaults => { :format => 'json' }
        end
        get 'media.:format' => 'media#show', :defaults => { :format => 'json' }, as: :media
        resources :audio_events, :defaults => { :format => 'json' } do
          collection do
            get 'download' , :defaults => { :format => 'csv' }, :constraints => {:format => /(csv)/}
          end
          resources :tags, :only => [:index], :defaults => { :format => 'json' }
          resources :taggings, :defaults => { :format => 'json' }
        end
      end
    end
    resources :sites, :only => [:index], :defaults => { :format => 'json' }
    resources :datasets, :except => [:index] do
      resources :jobs, :only => [:show]
      resources :jobs, :only => [:index], :defaults => { :format => 'json' }
    end
    resources :datasets, :only => [:index], :defaults => { :format => 'json' }
    resources :jobs, :except => [:index, :show]
    resources :jobs, :only => [:index], :defaults => { :format => 'json' }
  end

  # allow shallow paths to audio_recordings
  # TODO: cleanup unneccessary paths
  resources :audio_recordings, :only => [:show], :defaults => { :format => 'json' } do
    collection do
      get 'check_uploader', :defaults => { :format => 'json' }
    end
    get 'media.:format' => 'media#show', :defaults => { :format => 'json' }, as: :media
    resources :audio_events, :defaults => { :format => 'json' } do
      collection do
        get 'download' , :defaults => { :format => 'csv' }, :constraints => {:format => /(csv)/}
      end
      resources :tags, :only => [:index], :defaults => { :format => 'json' }
      resources :taggings, :defaults => { :format => 'json' }
    end
  end

  # routes for audio recordings and bookmarks within particular recordings
  resources :audio_recordings, :only => [], :defaults => { :format => 'json' }, shallow: true do
    member do
      put 'update_status'   # for when harvester has moved a file to the correct location
    end
    resources :bookmarks, :defaults => { :format => 'json' }
  end
  resources :tags, :defaults => { :format => 'json' }
  resources :audio_events, only: [:new], :defaults => { :format => 'json' }

  # custom routes for scripts
  resources :scripts, except: [:update, :destroy] do
    member do
      get 'versions' => 'scripts#versions', as: :versions
      get 'versions/:version_id' => 'scripts#version', as: :version
      post :update
    end
  end

  # shallow path to sites
  get '/sites/:id' => 'sites#show_shallow', defaults: {format: 'json'}

  # devise for RESTful API Authentication, see Api/sessions_controller.rb
  devise_for :users, :controllers => { :sessions => 'sessions' },
             :as => :security, :path => :security, :defaults => { :format => 'json' },
             :only => [ :sessions], :skip_helpers => true

  # route to the home page of site
  root :to => 'public#index'

  # route to access annotation tool
  get 'listen/:id' => 'listen#show'

  # when a user goes to my account, render user_account/show view for that user
  get '/my_account/' => 'user_accounts#my_account'

  # for updating only preferences for only the currently logged in user
  put '/my_account/prefs/' => 'user_accounts#modify_preferences'

  # provide access to API documentation
  mount Raddocs::App => '/doc'

  # for error pages
  match '*a', :to => 'errors#routing'

end
