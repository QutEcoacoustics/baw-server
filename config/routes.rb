# frozen_string_literal: true

# == Route Map
#
#                                                Prefix Verb                                         URI Pattern                                                                                                                          Controller#Action
#                                    rails_service_blob GET                                          /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                                                                  active_storage/blobs/redirect#show
#                              rails_service_blob_proxy GET                                          /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                                                     active_storage/blobs/proxy#show
#                                                       GET                                          /rails/active_storage/blobs/:signed_id/*filename(.:format)                                                                           active_storage/blobs/redirect#show
#                             rails_blob_representation GET                                          /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format)                                    active_storage/representations/redirect#show
#                       rails_blob_representation_proxy GET                                          /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)                                       active_storage/representations/proxy#show
#                                                       GET                                          /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)                                             active_storage/representations/redirect#show
#                                    rails_disk_service GET                                          /rails/active_storage/disk/:encoded_key/*filename(.:format)                                                                          active_storage/disk#show
#                             update_rails_disk_service PUT                                          /rails/active_storage/disk/:encoded_token(.:format)                                                                                  active_storage/disk#update
#                                  rails_direct_uploads POST                                         /rails/active_storage/direct_uploads(.:format)                                                                                       active_storage/direct_uploads#create
#                                              rswag_ui                                              /api-docs                                                                                                                            Rswag::Ui::Engine
#                                             rswag_api                                              /api-docs                                                                                                                            Rswag::Api::Engine
#                                      new_user_session GET                                          /my_account/sign_in(.:format)                                                                                                        users/sessions#new
#                                          user_session POST                                         /my_account/sign_in(.:format)                                                                                                        users/sessions#create
#                                  destroy_user_session GET                                          /my_account/sign_out(.:format)                                                                                                       users/sessions#destroy
#                                     new_user_password GET                                          /my_account/password/new(.:format)                                                                                                   devise/passwords#new
#                                    edit_user_password GET                                          /my_account/password/edit(.:format)                                                                                                  devise/passwords#edit
#                                         user_password PATCH                                        /my_account/password(.:format)                                                                                                       devise/passwords#update
#                                                       PUT                                          /my_account/password(.:format)                                                                                                       devise/passwords#update
#                                                       POST                                         /my_account/password(.:format)                                                                                                       devise/passwords#create
#                              cancel_user_registration GET                                          /my_account/cancel(.:format)                                                                                                         users/registrations#cancel
#                                 new_user_registration GET                                          /my_account/sign_up(.:format)                                                                                                        users/registrations#new
#                                edit_user_registration GET                                          /my_account/edit(.:format)                                                                                                           users/registrations#edit
#                                     user_registration PATCH                                        /my_account(.:format)                                                                                                                users/registrations#update
#                                                       PUT                                          /my_account(.:format)                                                                                                                users/registrations#update
#                                                       DELETE                                       /my_account(.:format)                                                                                                                users/registrations#destroy
#                                                       POST                                         /my_account(.:format)                                                                                                                users/registrations#create
#                                 new_user_confirmation GET                                          /my_account/confirmation/new(.:format)                                                                                               devise/confirmations#new
#                                     user_confirmation GET                                          /my_account/confirmation(.:format)                                                                                                   devise/confirmations#show
#                                                       POST                                         /my_account/confirmation(.:format)                                                                                                   devise/confirmations#create
#                                       new_user_unlock GET                                          /my_account/unlock/new(.:format)                                                                                                     devise/unlocks#new
#                                           user_unlock GET                                          /my_account/unlock(.:format)                                                                                                         devise/unlocks#show
#                                                       POST                                         /my_account/unlock(.:format)                                                                                                         devise/unlocks#create
#                                              security POST                                         /security(.:format)                                                                                                                  sessions#create {:format=>"json"}
#                                          security_new GET                                          /security/new(.:format)                                                                                                              sessions#new {:format=>"json"}
#                                         security_user GET                                          /security/user(.:format)                                                                                                             sessions#show {:format=>"json"}
#                                                       DELETE                                       /security(.:format)                                                                                                                  sessions#destroy {:format=>"json"}
#                                            my_account GET                                          /my_account(.:format)                                                                                                                user_accounts#my_account
#                                      my_account_prefs PUT                                          /my_account/prefs(.:format)                                                                                                          user_accounts#modify_preferences
#                                 projects_user_account GET                                          /user_accounts/:id/projects(.:format)                                                                                                user_accounts#projects {:id=>/[0-9]+/}
#                                    sites_user_account GET                                          /user_accounts/:id/sites(.:format)                                                                                                   user_accounts#sites {:id=>/[0-9]+/}
#                                bookmarks_user_account GET                                          /user_accounts/:id/bookmarks(.:format)                                                                                               user_accounts#bookmarks {:id=>/[0-9]+/}
#                             audio_events_user_account GET                                          /user_accounts/:id/audio_events(.:format)                                                                                            user_accounts#audio_events {:id=>/[0-9]+/}
#                     audio_event_comments_user_account GET                                          /user_accounts/:id/audio_event_comments(.:format)                                                                                    user_accounts#audio_event_comments {:id=>/[0-9]+/}
#                           saved_searches_user_account GET                                          /user_accounts/:id/saved_searches(.:format)                                                                                          user_accounts#saved_searches {:id=>/[0-9]+/}
#                            analysis_jobs_user_account GET                                          /user_accounts/:id/analysis_jobs(.:format)                                                                                           user_accounts#analysis_jobs {:id=>/[0-9]+/}
#                                  filter_user_accounts GET                                          /user_accounts/filter(.:format)                                                                                                      user_accounts#filter {:format=>"json"}
#                                                       POST                                         /user_accounts/filter(.:format)                                                                                                      user_accounts#filter {:format=>"json"}
#                                         user_accounts GET                                          /user_accounts(.:format)                                                                                                             user_accounts#index
#                                     edit_user_account GET                                          /user_accounts/:id/edit(.:format)                                                                                                    user_accounts#edit {:id=>/[0-9]+/}
#                                          user_account GET                                          /user_accounts/:id(.:format)                                                                                                         user_accounts#show {:id=>/[0-9]+/}
#                                                       PATCH                                        /user_accounts/:id(.:format)                                                                                                         user_accounts#update {:id=>/[0-9]+/}
#                                                       PUT                                          /user_accounts/:id(.:format)                                                                                                         user_accounts#update {:id=>/[0-9]+/}
#                                  internal_sftpgo_hook POST                                         /internal/sftpgo/hook(.:format)                                                                                                      internal/sftpgo#hook {:format=>"json"}
#                                      filter_bookmarks GET                                          /bookmarks/filter(.:format)                                                                                                          bookmarks#filter {:format=>"json"}
#                                                       POST                                         /bookmarks/filter(.:format)                                                                                                          bookmarks#filter {:format=>"json"}
#                                             bookmarks GET                                          /bookmarks(.:format)                                                                                                                 bookmarks#index
#                                                       POST                                         /bookmarks(.:format)                                                                                                                 bookmarks#create
#                                          new_bookmark GET                                          /bookmarks/new(.:format)                                                                                                             bookmarks#new
#                                              bookmark GET                                          /bookmarks/:id(.:format)                                                                                                             bookmarks#show
#                                                       PATCH                                        /bookmarks/:id(.:format)                                                                                                             bookmarks#update
#                                                       PUT                                          /bookmarks/:id(.:format)                                                                                                             bookmarks#update
#                                                       DELETE                                       /bookmarks/:id(.:format)                                                                                                             bookmarks#destroy
#                                                       GET|POST                                     /projects/:project_id/harvests/:harvest_id/items/filter(.:format)                                                                    harvest_items#filter {:format=>"json"}
#                                    edit_sites_project GET                                          /projects/:id/edit_sites(.:format)                                                                                                   projects#edit_sites
#                                  update_sites_project PUT                                          /projects/:id/update_sites(.:format)                                                                                                 projects#update_sites
#                                                       PATCH                                        /projects/:id/update_sites(.:format)                                                                                                 projects#update_sites
#                           new_access_request_projects GET                                          /projects/new_access_request(.:format)                                                                                               projects#new_access_request
#                        submit_access_request_projects POST                                         /projects/submit_access_request(.:format)                                                                                            projects#submit_access_request
#                                   project_permissions GET                                          /projects/:project_id/permissions(.:format)                                                                                          permissions#index
#                            filter_project_permissions GET                                          /projects/:project_id/permissions/filter(.:format)                                                                                   permissions#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/permissions/filter(.:format)                                                                                   permissions#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/permissions(.:format)                                                                                          permissions#create {:format=>"json"}
#                                new_project_permission GET                                          /projects/:project_id/permissions/new(.:format)                                                                                      permissions#new {:format=>"json"}
#                                    project_permission GET                                          /projects/:project_id/permissions/:id(.:format)                                                                                      permissions#show {:format=>"json"}
#                                                       PATCH                                        /projects/:project_id/permissions/:id(.:format)                                                                                      permissions#update {:format=>"json"}
#                                                       PUT                                          /projects/:project_id/permissions/:id(.:format)                                                                                      permissions#update {:format=>"json"}
#                                                       DELETE                                       /projects/:project_id/permissions/:id(.:format)                                                                                      permissions#destroy {:format=>"json"}
#                      upload_instructions_project_site GET                                          /projects/:project_id/sites/:id/upload_instructions(.:format)                                                                        sites#upload_instructions
#                                  harvest_project_site GET                                          /projects/:project_id/sites/:id/harvest(.:format)                                                                                    sites#harvest
#                                                       GET                                          /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id(.:format)                                          audio_recordings#check_uploader {:format=>"json"}
#                  filter_project_site_audio_recordings GET                                          /projects/:project_id/sites/:site_id/audio_recordings/filter(.:format)                                                               audio_recordings#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/sites/:site_id/audio_recordings/filter(.:format)                                                               audio_recordings#filter {:format=>"json"}
#                         project_site_audio_recordings POST                                         /projects/:project_id/sites/:site_id/audio_recordings(.:format)                                                                      audio_recordings#create {:format=>"json"}
#                      new_project_site_audio_recording GET                                          /projects/:project_id/sites/:site_id/audio_recordings/new(.:format)                                                                  audio_recordings#new {:format=>"json"}
#                                  filter_project_sites GET                                          /projects/:project_id/sites/filter(.:format)                                                                                         sites#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/sites/filter(.:format)                                                                                         sites#filter {:format=>"json"}
#                                         project_sites POST                                         /projects/:project_id/sites(.:format)                                                                                                sites#create
#                                      new_project_site GET                                          /projects/:project_id/sites/new(.:format)                                                                                            sites#new
#                                     edit_project_site GET                                          /projects/:project_id/sites/:id/edit(.:format)                                                                                       sites#edit
#                                          project_site GET                                          /projects/:project_id/sites/:id(.:format)                                                                                            sites#show
#                                                       PATCH                                        /projects/:project_id/sites/:id(.:format)                                                                                            sites#update
#                                                       PUT                                          /projects/:project_id/sites/:id(.:format)                                                                                            sites#update
#                                                       DELETE                                       /projects/:project_id/sites/:id(.:format)                                                                                            sites#destroy
#                                                       GET                                          /projects/:project_id/sites/filter(.:format)                                                                                         sites#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/sites/filter(.:format)                                                                                         sites#filter {:format=>"json"}
#                                                       GET                                          /projects/:project_id/sites(.:format)                                                                                                sites#index {:format=>"json"}
#                                filter_project_regions GET                                          /projects/:project_id/regions/filter(.:format)                                                                                       regions#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/regions/filter(.:format)                                                                                       regions#filter {:format=>"json"}
#                                       project_regions GET                                          /projects/:project_id/regions(.:format)                                                                                              regions#index {:format=>"json"}
#                                                       POST                                         /projects/:project_id/regions(.:format)                                                                                              regions#create {:format=>"json"}
#                                    new_project_region GET                                          /projects/:project_id/regions/new(.:format)                                                                                          regions#new {:format=>"json"}
#                                        project_region GET                                          /projects/:project_id/regions/:id(.:format)                                                                                          regions#show {:format=>"json"}
#                                                       PATCH                                        /projects/:project_id/regions/:id(.:format)                                                                                          regions#update {:format=>"json"}
#                                                       PUT                                          /projects/:project_id/regions/:id(.:format)                                                                                          regions#update {:format=>"json"}
#                                                       DELETE                                       /projects/:project_id/regions/:id(.:format)                                                                                          regions#destroy {:format=>"json"}
#                                                       GET                                          /projects/:project_id/harvests/:harvest_id/items(/*path)                                                                             harvest_items#index {:format=>"json"}
#                               filter_project_harvests GET                                          /projects/:project_id/harvests/filter(.:format)                                                                                      harvests#filter {:format=>"json"}
#                                                       POST                                         /projects/:project_id/harvests/filter(.:format)                                                                                      harvests#filter {:format=>"json"}
#                                      project_harvests GET                                          /projects/:project_id/harvests(.:format)                                                                                             harvests#index {:format=>"json"}
#                                                       POST                                         /projects/:project_id/harvests(.:format)                                                                                             harvests#create {:format=>"json"}
#                                   new_project_harvest GET                                          /projects/:project_id/harvests/new(.:format)                                                                                         harvests#new {:format=>"json"}
#                                       project_harvest GET                                          /projects/:project_id/harvests/:id(.:format)                                                                                         harvests#show {:format=>"json"}
#                                                       PATCH                                        /projects/:project_id/harvests/:id(.:format)                                                                                         harvests#update {:format=>"json"}
#                                                       PUT                                          /projects/:project_id/harvests/:id(.:format)                                                                                         harvests#update {:format=>"json"}
#                                                       DELETE                                       /projects/:project_id/harvests/:id(.:format)                                                                                         harvests#destroy {:format=>"json"}
#                                       filter_projects GET                                          /projects/filter(.:format)                                                                                                           projects#filter {:format=>"json"}
#                                                       POST                                         /projects/filter(.:format)                                                                                                           projects#filter {:format=>"json"}
#                                              projects GET                                          /projects(.:format)                                                                                                                  projects#index
#                                                       POST                                         /projects(.:format)                                                                                                                  projects#create
#                                           new_project GET                                          /projects/new(.:format)                                                                                                              projects#new
#                                          edit_project GET                                          /projects/:id/edit(.:format)                                                                                                         projects#edit
#                                               project GET                                          /projects/:id(.:format)                                                                                                              projects#show
#                                                       PATCH                                        /projects/:id(.:format)                                                                                                              projects#update
#                                                       PUT                                          /projects/:id(.:format)                                                                                                              projects#update
#                                                       DELETE                                       /projects/:id(.:format)                                                                                                              projects#destroy
#                           analysis_jobs_results_index GET|HEAD                                     /analysis_jobs/:analysis_job_id/results                                                                                              analysis_jobs_results#index {:format=>"json"}
#                            analysis_jobs_results_show GET|HEAD                                     /analysis_jobs/:analysis_job_id/results/:audio_recording_id(/*results_path)                                                          analysis_jobs_results#show {:format=>"json"}
#                             filter_analysis_job_items GET                                          /analysis_jobs/:analysis_job_id/items/filter(.:format)                                                                               analysis_jobs_items#filter {:format=>"json"}
#                                                       POST                                         /analysis_jobs/:analysis_job_id/items/filter(.:format)                                                                               analysis_jobs_items#filter {:format=>"json"}
#                                                       PUT                                          /analysis_jobs/:analysis_job_id/items/:id/:invoke_action(.:format)                                                                   analysis_jobs_items#invoke {:format=>"json"}
#                              invoke_analysis_job_item POST                                         /analysis_jobs/:analysis_job_id/items/:id/:invoke_action(.:format)                                                                   analysis_jobs_items#invoke {:format=>"json"}
#                                    analysis_job_items GET                                          /analysis_jobs/:analysis_job_id/items(.:format)                                                                                      analysis_jobs_items#index {:format=>"json"}
#                                     analysis_job_item GET                                          /analysis_jobs/:analysis_job_id/items/:id(.:format)                                                                                  analysis_jobs_items#show {:format=>"json"}
#                                  filter_analysis_jobs GET                                          /analysis_jobs/filter(.:format)                                                                                                      analysis_jobs#filter {:format=>"json"}
#                                                       POST                                         /analysis_jobs/filter(.:format)                                                                                                      analysis_jobs#filter {:format=>"json"}
#                                                       PUT                                          /analysis_jobs/:id/:invoke_action(.:format)                                                                                          analysis_jobs#invoke {:format=>"json"}
#                                   invoke_analysis_job POST                                         /analysis_jobs/:id/:invoke_action(.:format)                                                                                          analysis_jobs#invoke {:format=>"json"}
#                                         analysis_jobs GET                                          /analysis_jobs(.:format)                                                                                                             analysis_jobs#index {:format=>"json"}
#                                                       POST                                         /analysis_jobs(.:format)                                                                                                             analysis_jobs#create {:format=>"json"}
#                                      new_analysis_job GET                                          /analysis_jobs/new(.:format)                                                                                                         analysis_jobs#new {:format=>"json"}
#                                          analysis_job GET                                          /analysis_jobs/:id(.:format)                                                                                                         analysis_jobs#show {:format=>"json"}
#                                                       PATCH                                        /analysis_jobs/:id(.:format)                                                                                                         analysis_jobs#update {:format=>"json"}
#                                                       PUT                                          /analysis_jobs/:id(.:format)                                                                                                         analysis_jobs#update {:format=>"json"}
#                                                       DELETE                                       /analysis_jobs/:id(.:format)                                                                                                         analysis_jobs#destroy {:format=>"json"}
#                                 filter_saved_searches GET                                          /saved_searches/filter(.:format)                                                                                                     saved_searches#filter {:format=>"json"}
#                                                       POST                                         /saved_searches/filter(.:format)                                                                                                     saved_searches#filter {:format=>"json"}
#                                        saved_searches GET                                          /saved_searches(.:format)                                                                                                            saved_searches#index {:format=>"json"}
#                                                       POST                                         /saved_searches(.:format)                                                                                                            saved_searches#create {:format=>"json"}
#                                      new_saved_search GET                                          /saved_searches/new(.:format)                                                                                                        saved_searches#new {:format=>"json"}
#                                          saved_search GET                                          /saved_searches/:id(.:format)                                                                                                        saved_searches#show {:format=>"json"}
#                                                       DELETE                                       /saved_searches/:id(.:format)                                                                                                        saved_searches#destroy {:format=>"json"}
#                           audio_recordings_downloader GET|POST                                     /audio_recordings/downloader(.:format)                                                                                               audio_recordings/downloader#index {:format=>"json"}
#                                       taggings_filter GET|POST                                     /taggings/filter(.:format)                                                                                                           taggings#filter {:format=>"json"}
#                                 audio_recording_media GET|HEAD                                     /audio_recordings/:audio_recording_id/media.:format                                                                                  media#show {:format=>"json"}
#                        audio_recording_media_original GET|HEAD                                     /audio_recordings/:audio_recording_id/original(.:format)                                                                             media#original {:format=>false}
#                 download_audio_recording_audio_events GET                                          /audio_recordings/:audio_recording_id/audio_events/download(.:format)                                                                audio_events#download {:format=>"csv"}
#                      audio_recording_audio_event_tags GET                                          /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/tags(.:format)                                                    tags#index {:format=>"json"}
#                  audio_recording_audio_event_taggings GET                                          /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings(.:format)                                                taggings#index {:format=>"json"}
#                                                       POST                                         /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings(.:format)                                                taggings#create {:format=>"json"}
#               new_audio_recording_audio_event_tagging GET                                          /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/new(.:format)                                            taggings#new {:format=>"json"}
#                   audio_recording_audio_event_tagging GET                                          /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id(.:format)                                            taggings#show {:format=>"json"}
#                                                       PATCH                                        /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id(.:format)                                            taggings#update {:format=>"json"}
#                                                       PUT                                          /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id(.:format)                                            taggings#update {:format=>"json"}
#                                                       DELETE                                       /audio_recordings/:audio_recording_id/audio_events/:audio_event_id/taggings/:id(.:format)                                            taggings#destroy {:format=>"json"}
#                   filter_audio_recording_audio_events GET                                          /audio_recordings/:audio_recording_id/audio_events/filter(.:format)                                                                  audio_events#filter {:format=>"json"}
#                                                       POST                                         /audio_recordings/:audio_recording_id/audio_events/filter(.:format)                                                                  audio_events#filter {:format=>"json"}
#                          audio_recording_audio_events GET                                          /audio_recordings/:audio_recording_id/audio_events(.:format)                                                                         audio_events#index {:format=>"json"}
#                                                       POST                                         /audio_recordings/:audio_recording_id/audio_events(.:format)                                                                         audio_events#create {:format=>"json"}
#                       new_audio_recording_audio_event GET                                          /audio_recordings/:audio_recording_id/audio_events/new(.:format)                                                                     audio_events#new {:format=>"json"}
#                           audio_recording_audio_event GET                                          /audio_recordings/:audio_recording_id/audio_events/:id(.:format)                                                                     audio_events#show {:format=>"json"}
#                                                       PATCH                                        /audio_recordings/:audio_recording_id/audio_events/:id(.:format)                                                                     audio_events#update {:format=>"json"}
#                                                       PUT                                          /audio_recordings/:audio_recording_id/audio_events/:id(.:format)                                                                     audio_events#update {:format=>"json"}
#                                                       DELETE                                       /audio_recordings/:audio_recording_id/audio_events/:id(.:format)                                                                     audio_events#destroy {:format=>"json"}
#                               filter_audio_recordings GET                                          /audio_recordings/filter(.:format)                                                                                                   audio_recordings#filter {:format=>"json"}
#                                                       POST                                         /audio_recordings/filter(.:format)                                                                                                   audio_recordings#filter {:format=>"json"}
#                                      audio_recordings GET                                          /audio_recordings(.:format)                                                                                                          audio_recordings#index {:format=>"json"}
#                                   new_audio_recording GET                                          /audio_recordings/new(.:format)                                                                                                      audio_recordings#new {:format=>"json"}
#                                       audio_recording GET                                          /audio_recordings/:id(.:format)                                                                                                      audio_recordings#show {:format=>"json"}
#                                                       PATCH                                        /audio_recordings/:id(.:format)                                                                                                      audio_recordings#update {:format=>"json"}
#                                                       PUT                                          /audio_recordings/:id(.:format)                                                                                                      audio_recordings#update {:format=>"json"}
#                         update_status_audio_recording PUT                                          /audio_recordings/:id/update_status(.:format)                                                                                        audio_recordings#update_status {:format=>"json"}
#                                                       GET                                          /audio_recordings/filter(.:format)                                                                                                   audio_recordings#filter {:format=>"json"}
#                                                       POST                                         /audio_recordings/filter(.:format)                                                                                                   audio_recordings#filter {:format=>"json"}
#                                           filter_tags GET                                          /tags/filter(.:format)                                                                                                               tags#filter {:format=>"json"}
#                                                       POST                                         /tags/filter(.:format)                                                                                                               tags#filter {:format=>"json"}
#                                                  tags GET                                          /tags(.:format)                                                                                                                      tags#index {:format=>"json"}
#                                                       POST                                         /tags(.:format)                                                                                                                      tags#create {:format=>"json"}
#                                               new_tag GET                                          /tags/new(.:format)                                                                                                                  tags#new {:format=>"json"}
#                                                   tag GET                                          /tags/:id(.:format)                                                                                                                  tags#show {:format=>"json"}
#                           filter_audio_event_comments GET                                          /audio_events/:audio_event_id/comments/filter(.:format)                                                                              audio_event_comments#filter {:format=>"json"}
#                                                       POST                                         /audio_events/:audio_event_id/comments/filter(.:format)                                                                              audio_event_comments#filter {:format=>"json"}
#                                  audio_event_comments GET                                          /audio_events/:audio_event_id/comments(.:format)                                                                                     audio_event_comments#index {:format=>"json"}
#                                                       POST                                         /audio_events/:audio_event_id/comments(.:format)                                                                                     audio_event_comments#create {:format=>"json"}
#                               new_audio_event_comment GET                                          /audio_events/:audio_event_id/comments/new(.:format)                                                                                 audio_event_comments#new {:format=>"json"}
#                                   audio_event_comment GET                                          /audio_events/:audio_event_id/comments/:id(.:format)                                                                                 audio_event_comments#show {:format=>"json"}
#                                                       PATCH                                        /audio_events/:audio_event_id/comments/:id(.:format)                                                                                 audio_event_comments#update {:format=>"json"}
#                                                       PUT                                          /audio_events/:audio_event_id/comments/:id(.:format)                                                                                 audio_event_comments#update {:format=>"json"}
#                                                       DELETE                                       /audio_events/:audio_event_id/comments/:id(.:format)                                                                                 audio_event_comments#destroy {:format=>"json"}
#                                   filter_audio_events GET                                          /audio_events/filter(.:format)                                                                                                       audio_events#filter {:format=>"json"}
#                                                       POST                                         /audio_events/filter(.:format)                                                                                                       audio_events#filter {:format=>"json"}
#                                    filter_provenances GET                                          /provenances/filter(.:format)                                                                                                        provenances#filter {:format=>"json"}
#                                                       POST                                         /provenances/filter(.:format)                                                                                                        provenances#filter {:format=>"json"}
#                                           provenances GET                                          /provenances(.:format)                                                                                                               provenances#index {:format=>"json"}
#                                                       POST                                         /provenances(.:format)                                                                                                               provenances#create {:format=>"json"}
#                                        new_provenance GET                                          /provenances/new(.:format)                                                                                                           provenances#new {:format=>"json"}
#                                            provenance GET                                          /provenances/:id(.:format)                                                                                                           provenances#show {:format=>"json"}
#                                                       PATCH                                        /provenances/:id(.:format)                                                                                                           provenances#update {:format=>"json"}
#                                                       PUT                                          /provenances/:id(.:format)                                                                                                           provenances#update {:format=>"json"}
#                                                       DELETE                                       /provenances/:id(.:format)                                                                                                           provenances#destroy {:format=>"json"}
#                            filter_audio_event_imports GET                                          /audio_event_imports/filter(.:format)                                                                                                audio_event_imports#filter {:format=>"json"}
#                                                       POST                                         /audio_event_imports/filter(.:format)                                                                                                audio_event_imports#filter {:format=>"json"}
#                                   audio_event_imports GET                                          /audio_event_imports(.:format)                                                                                                       audio_event_imports#index {:format=>"json"}
#                                                       POST                                         /audio_event_imports(.:format)                                                                                                       audio_event_imports#create {:format=>"json"}
#                                new_audio_event_import GET                                          /audio_event_imports/new(.:format)                                                                                                   audio_event_imports#new {:format=>"json"}
#                                    audio_event_import GET                                          /audio_event_imports/:id(.:format)                                                                                                   audio_event_imports#show {:format=>"json"}
#                                                       PATCH                                        /audio_event_imports/:id(.:format)                                                                                                   audio_event_imports#update {:format=>"json"}
#                                                       PUT                                          /audio_event_imports/:id(.:format)                                                                                                   audio_event_imports#update {:format=>"json"}
#                                                       DELETE                                       /audio_event_imports/:id(.:format)                                                                                                   audio_event_imports#destroy {:format=>"json"}
#                                        filter_scripts GET                                          /scripts/filter(.:format)                                                                                                            scripts#filter {:format=>"json"}
#                                                       POST                                         /scripts/filter(.:format)                                                                                                            scripts#filter {:format=>"json"}
#                                               scripts GET                                          /scripts(.:format)                                                                                                                   scripts#index {:format=>"json"}
#                                                script GET                                          /scripts/:id(.:format)                                                                                                               scripts#show {:format=>"json"}
#                                         user_taggings GET                                          /user_accounts/:user_id/taggings(.:format)                                                                                           taggings#user_index {:format=>"json"}
#                         download_project_audio_events GET                                          /projects/:project_id/audio_events/download(.:format)                                                                                audio_events#download {:format=>"csv"}
#                            download_site_audio_events GET                                          /projects/:project_id/sites/:site_id/audio_events/download(.:format)                                                                 audio_events#download {:format=>"csv"}
#                            download_user_audio_events GET                                          /user_accounts/:user_id/audio_events/download(.:format)                                                                              audio_events#download {:format=>"csv"}
#                                         sites_orphans GET                                          /sites/orphans(.:format)                                                                                                             sites#orphans
#                                  sites_orphans_filter GET|POST                                     /sites/orphans/filter(.:format)                                                                                                      sites#orphans {:format=>"json"}
#                             filter_shallow_site_index GET                                          /sites/filter(.:format)                                                                                                              sites#filter {:format=>"json"}
#                                                       POST                                         /sites/filter(.:format)                                                                                                              sites#filter {:format=>"json"}
#                                    shallow_site_index GET                                          /sites(.:format)                                                                                                                     sites#index {:format=>"json"}
#                                                       POST                                         /sites(.:format)                                                                                                                     sites#create {:format=>"json"}
#                                      new_shallow_site GET                                          /sites/new(.:format)                                                                                                                 sites#new {:format=>"json"}
#                                          shallow_site GET                                          /sites/:id(.:format)                                                                                                                 sites#show {:format=>"json"}
#                                                       PATCH                                        /sites/:id(.:format)                                                                                                                 sites#update {:format=>"json"}
#                                                       PUT                                          /sites/:id(.:format)                                                                                                                 sites#update {:format=>"json"}
#                                                       DELETE                                       /sites/:id(.:format)                                                                                                                 sites#destroy {:format=>"json"}
#                           filter_shallow_region_index GET                                          /regions/filter(.:format)                                                                                                            regions#filter {:format=>"json"}
#                                                       POST                                         /regions/filter(.:format)                                                                                                            regions#filter {:format=>"json"}
#                                  shallow_region_index GET                                          /regions(.:format)                                                                                                                   regions#index {:format=>"json"}
#                                                       POST                                         /regions(.:format)                                                                                                                   regions#create {:format=>"json"}
#                                    new_shallow_region GET                                          /regions/new(.:format)                                                                                                               regions#new {:format=>"json"}
#                                        shallow_region GET                                          /regions/:id(.:format)                                                                                                               regions#show {:format=>"json"}
#                                                       PATCH                                        /regions/:id(.:format)                                                                                                               regions#update {:format=>"json"}
#                                                       PUT                                          /regions/:id(.:format)                                                                                                               regions#update {:format=>"json"}
#                                                       DELETE                                       /regions/:id(.:format)                                                                                                               regions#destroy {:format=>"json"}
#                                                       GET|POST                                     /harvests/:harvest_id/items/filter(.:format)                                                                                         harvest_items#filter {:format=>"json"}
#                                                       GET                                          /harvests/:harvest_id/items(/*path)                                                                                                  harvest_items#index {:format=>"json"}
#                                  filter_harvest_index GET                                          /harvests/filter(.:format)                                                                                                           harvests#filter {:format=>"json"}
#                                                       POST                                         /harvests/filter(.:format)                                                                                                           harvests#filter {:format=>"json"}
#                                         harvest_index GET                                          /harvests(.:format)                                                                                                                  harvests#index {:format=>"json"}
#                                                       POST                                         /harvests(.:format)                                                                                                                  harvests#create {:format=>"json"}
#                                           new_harvest GET                                          /harvests/new(.:format)                                                                                                              harvests#new {:format=>"json"}
#                                               harvest GET                                          /harvests/:id(.:format)                                                                                                              harvests#show {:format=>"json"}
#                                                       PATCH                                        /harvests/:id(.:format)                                                                                                              harvests#update {:format=>"json"}
#                                                       PUT                                          /harvests/:id(.:format)                                                                                                              harvests#update {:format=>"json"}
#                                                       DELETE                                       /harvests/:id(.:format)                                                                                                              harvests#destroy {:format=>"json"}
#                                                       POST                                         /datasets/:dataset_id/progress_events/audio_recordings/:audio_recording_id/start/:start_time_seconds/end/:end_time_seconds(.:format) progress_events#create_by_dataset_item_params {:format=>"json", :dataset_id=>/(\d+|default)/, :audio_recording_id=>/\d+/, :start_time_seconds=>/\d+(\.\d+)?/, :end_time_seconds=>/\d+(\.\d+)?/}
#                                                       GET                                          /datasets/:dataset_id/dataset_items/next_for_me(.:format)                                                                            dataset_items#next_for_me {:format=>"json"}
#                                  filter_dataset_items GET                                          /datasets/:dataset_id/items/filter(.:format)                                                                                         dataset_items#filter {:format=>"json"}
#                                                       POST                                         /datasets/:dataset_id/items/filter(.:format)                                                                                         dataset_items#filter {:format=>"json"}
#                                         dataset_items GET                                          /datasets/:dataset_id/items(.:format)                                                                                                dataset_items#index {:format=>"json"}
#                                                       POST                                         /datasets/:dataset_id/items(.:format)                                                                                                dataset_items#create {:format=>"json"}
#                                      new_dataset_item GET                                          /datasets/:dataset_id/items/new(.:format)                                                                                            dataset_items#new {:format=>"json"}
#                                     edit_dataset_item GET                                          /datasets/:dataset_id/items/:id/edit(.:format)                                                                                       dataset_items#edit {:format=>"json"}
#                                          dataset_item GET                                          /datasets/:dataset_id/items/:id(.:format)                                                                                            dataset_items#show {:format=>"json"}
#                                                       PATCH                                        /datasets/:dataset_id/items/:id(.:format)                                                                                            dataset_items#update {:format=>"json"}
#                                                       PUT                                          /datasets/:dataset_id/items/:id(.:format)                                                                                            dataset_items#update {:format=>"json"}
#                                                       DELETE                                       /datasets/:dataset_id/items/:id(.:format)                                                                                            dataset_items#destroy {:format=>"json"}
#                                       filter_datasets GET                                          /datasets/filter(.:format)                                                                                                           datasets#filter {:format=>"json"}
#                                                       POST                                         /datasets/filter(.:format)                                                                                                           datasets#filter {:format=>"json"}
#                                              datasets GET                                          /datasets(.:format)                                                                                                                  datasets#index {:format=>"json"}
#                                                       POST                                         /datasets(.:format)                                                                                                                  datasets#create {:format=>"json"}
#                                           new_dataset GET                                          /datasets/new(.:format)                                                                                                              datasets#new {:format=>"json"}
#                                          edit_dataset GET                                          /datasets/:id/edit(.:format)                                                                                                         datasets#edit {:format=>"json"}
#                                               dataset GET                                          /datasets/:id(.:format)                                                                                                              datasets#show {:format=>"json"}
#                                                       PATCH                                        /datasets/:id(.:format)                                                                                                              datasets#update {:format=>"json"}
#                                                       PUT                                          /datasets/:id(.:format)                                                                                                              datasets#update {:format=>"json"}
#                                                       PUT                                          /responses/:id(.:format)                                                                                                             errors#method_not_allowed_error
#                                                       PUT                                          /studies/:study_id/responses/:id(.:format)                                                                                           errors#method_not_allowed
#                                        filter_studies GET                                          /studies/filter(.:format)                                                                                                            studies#filter {:format=>"json"}
#                                                       POST                                         /studies/filter(.:format)                                                                                                            studies#filter {:format=>"json"}
#                                               studies GET                                          /studies(.:format)                                                                                                                   studies#index {:format=>"json"}
#                                                       POST                                         /studies(.:format)                                                                                                                   studies#create {:format=>"json"}
#                                             new_study GET                                          /studies/new(.:format)                                                                                                               studies#new {:format=>"json"}
#                                            edit_study GET                                          /studies/:id/edit(.:format)                                                                                                          studies#edit {:format=>"json"}
#                                                 study GET                                          /studies/:id(.:format)                                                                                                               studies#show {:format=>"json"}
#                                                       PATCH                                        /studies/:id(.:format)                                                                                                               studies#update {:format=>"json"}
#                                                       PUT                                          /studies/:id(.:format)                                                                                                               studies#update {:format=>"json"}
#                                                       DELETE                                       /studies/:id(.:format)                                                                                                               studies#destroy {:format=>"json"}
#                                      filter_questions GET                                          /questions/filter(.:format)                                                                                                          questions#filter {:format=>"json"}
#                                                       POST                                         /questions/filter(.:format)                                                                                                          questions#filter {:format=>"json"}
#                                             questions GET                                          /questions(.:format)                                                                                                                 questions#index {:format=>"json"}
#                                                       POST                                         /questions(.:format)                                                                                                                 questions#create {:format=>"json"}
#                                          new_question GET                                          /questions/new(.:format)                                                                                                             questions#new {:format=>"json"}
#                                         edit_question GET                                          /questions/:id/edit(.:format)                                                                                                        questions#edit {:format=>"json"}
#                                              question GET                                          /questions/:id(.:format)                                                                                                             questions#show {:format=>"json"}
#                                                       PATCH                                        /questions/:id(.:format)                                                                                                             questions#update {:format=>"json"}
#                                                       PUT                                          /questions/:id(.:format)                                                                                                             questions#update {:format=>"json"}
#                                                       DELETE                                       /questions/:id(.:format)                                                                                                             questions#destroy {:format=>"json"}
#                                      filter_responses GET                                          /responses/filter(.:format)                                                                                                          responses#filter {:format=>"json"}
#                                                       POST                                         /responses/filter(.:format)                                                                                                          responses#filter {:format=>"json"}
#                                             responses GET                                          /responses(.:format)                                                                                                                 responses#index {:format=>"json"}
#                                                       POST                                         /responses(.:format)                                                                                                                 responses#create {:format=>"json"}
#                                          new_response GET                                          /responses/new(.:format)                                                                                                             responses#new {:format=>"json"}
#                                         edit_response GET                                          /responses/:id/edit(.:format)                                                                                                        responses#edit {:format=>"json"}
#                                              response GET                                          /responses/:id(.:format)                                                                                                             responses#show {:format=>"json"}
#                                                       DELETE                                       /responses/:id(.:format)                                                                                                             responses#destroy {:format=>"json"}
#                                                       GET                                          /studies/:study_id/questions(.:format)                                                                                               questions#index {:format=>"json"}
#                                                       GET                                          /studies/:study_id/responses(.:format)                                                                                               responses#index {:format=>"json"}
#                                                       POST                                         /studies/:study_id/questions/:question_id/responses(.:format)                                                                        responses#create {:format=>"json"}
#                                filter_progress_events GET                                          /progress_events/filter(.:format)                                                                                                    progress_events#filter {:format=>"json"}
#                                                       POST                                         /progress_events/filter(.:format)                                                                                                    progress_events#filter {:format=>"json"}
#                                       progress_events GET                                          /progress_events(.:format)                                                                                                           progress_events#index {:format=>"json"}
#                                                       POST                                         /progress_events(.:format)                                                                                                           progress_events#create {:format=>"json"}
#                                    new_progress_event GET                                          /progress_events/new(.:format)                                                                                                       progress_events#new {:format=>"json"}
#                                   edit_progress_event GET                                          /progress_events/:id/edit(.:format)                                                                                                  progress_events#edit {:format=>"json"}
#                                        progress_event GET                                          /progress_events/:id(.:format)                                                                                                       progress_events#show {:format=>"json"}
#                                                       PATCH                                        /progress_events/:id(.:format)                                                                                                       progress_events#update {:format=>"json"}
#                                                       PUT                                          /progress_events/:id(.:format)                                                                                                       progress_events#update {:format=>"json"}
#                                                       DELETE                                       /progress_events/:id(.:format)                                                                                                       progress_events#destroy {:format=>"json"}
#                                                  root GET                                          /                                                                                                                                    public#index
#                                                status GET                                          /status(.:format)                                                                                                                    status#index {:format=>"json"}
#                                        website_status GET                                          /website_status(.:format)                                                                                                            public#website_status
#                                                 stats GET                                          /stats(.:format)                                                                                                                     stats#index {:format=>"json"}
#                                            contact_us GET                                          /contact_us(.:format)                                                                                                                public#new_contact_us
#                                                       POST                                         /contact_us(.:format)                                                                                                                public#create_contact_us
#                                            bug_report GET                                          /bug_report(.:format)                                                                                                                public#new_bug_report
#                                                       POST                                         /bug_report(.:format)                                                                                                                public#create_bug_report
#                                          data_request GET                                          /data_request(.:format)                                                                                                              public#new_data_request
#                                                       POST                                         /data_request(.:format)                                                                                                              public#create_data_request
#                                           disclaimers GET                                          /disclaimers(.:format)                                                                                                               public#disclaimers
#                                      ethics_statement GET                                          /ethics_statement(.:format)                                                                                                          public#ethics_statement
#                                           data_upload GET                                          /data_upload(.:format)                                                                                                               public#data_upload
#                                               credits GET                                          /credits(.:format)                                                                                                                   public#credits
#                                                                                                    /job_queue_status                                                                                                                    #<Resque::Server app_file="/usr/local/bundle/gems/resque-2.5.0/lib/resque/server.rb">
#                                       admin_dashboard GET                                          /admin(.:format)                                                                                                                     admin/home#index
#                                            admin_tags GET                                          /admin/tags(.:format)                                                                                                                admin/tags#index
#                                                       POST                                         /admin/tags(.:format)                                                                                                                admin/tags#create
#                                         new_admin_tag GET                                          /admin/tags/new(.:format)                                                                                                            admin/tags#new
#                                        edit_admin_tag GET                                          /admin/tags/:id/edit(.:format)                                                                                                       admin/tags#edit
#                                             admin_tag GET                                          /admin/tags/:id(.:format)                                                                                                            admin/tags#show
#                                                       PATCH                                        /admin/tags/:id(.:format)                                                                                                            admin/tags#update
#                                                       PUT                                          /admin/tags/:id(.:format)                                                                                                            admin/tags#update
#                                                       DELETE                                       /admin/tags/:id(.:format)                                                                                                            admin/tags#destroy
#                                      admin_tag_groups GET                                          /admin/tag_groups(.:format)                                                                                                          admin/tag_groups#index
#                                                       POST                                         /admin/tag_groups(.:format)                                                                                                          admin/tag_groups#create
#                                   new_admin_tag_group GET                                          /admin/tag_groups/new(.:format)                                                                                                      admin/tag_groups#new
#                                  edit_admin_tag_group GET                                          /admin/tag_groups/:id/edit(.:format)                                                                                                 admin/tag_groups#edit
#                                       admin_tag_group GET                                          /admin/tag_groups/:id(.:format)                                                                                                      admin/tag_groups#show
#                                                       PATCH                                        /admin/tag_groups/:id(.:format)                                                                                                      admin/tag_groups#update
#                                                       PUT                                          /admin/tag_groups/:id(.:format)                                                                                                      admin/tag_groups#update
#                                                       DELETE                                       /admin/tag_groups/:id(.:format)                                                                                                      admin/tag_groups#destroy
#                                admin_audio_recordings GET                                          /admin/audio_recordings(.:format)                                                                                                    admin/audio_recordings#index
#                                 admin_audio_recording GET                                          /admin/audio_recordings/:id(.:format)                                                                                                admin/audio_recordings#show
#                                   admin_analysis_jobs GET                                          /admin/analysis_jobs(.:format)                                                                                                       admin/analysis_jobs#index
#                                    admin_analysis_job GET                                          /admin/analysis_jobs/:id(.:format)                                                                                                   admin/analysis_jobs#show
#                                          admin_script POST                                         /admin/scripts/:id(.:format)                                                                                                         admin/scripts#update
#                                         admin_scripts GET                                          /admin/scripts(.:format)                                                                                                             admin/scripts#index
#                                                       POST                                         /admin/scripts(.:format)                                                                                                             admin/scripts#create
#                                      new_admin_script GET                                          /admin/scripts/new(.:format)                                                                                                         admin/scripts#new
#                                     edit_admin_script GET                                          /admin/scripts/:id/edit(.:format)                                                                                                    admin/scripts#edit
#                                                       GET                                          /admin/scripts/:id(.:format)                                                                                                         admin/scripts#show
#                                                       DELETE                                       /admin/scripts/:id(.:format)                                                                                                         admin/scripts#destroy
#                                                       OPTIONS                                      /*requested_route(.:format)                                                                                                          public#cors_preflight
#                                       comfy_admin_cms GET                                          /admin/cms(.:format)                                                                                                                 comfy/admin/cms/base#jump
#                    reorder_comfy_admin_cms_site_pages PUT                                          /admin/cms/sites/:site_id/pages/reorder(.:format)                                                                                    comfy/admin/cms/pages#reorder
#              form_fragments_comfy_admin_cms_site_page GET                                          /admin/cms/sites/:site_id/pages/:id/form_fragments(.:format)                                                                         comfy/admin/cms/pages#form_fragments
#             revert_comfy_admin_cms_site_page_revision PATCH                                        /admin/cms/sites/:site_id/pages/:page_id/revisions/:id/revert(.:format)                                                              comfy/admin/cms/revisions/page#revert
#                   comfy_admin_cms_site_page_revisions GET                                          /admin/cms/sites/:site_id/pages/:page_id/revisions(.:format)                                                                         comfy/admin/cms/revisions/page#index
#                    comfy_admin_cms_site_page_revision GET                                          /admin/cms/sites/:site_id/pages/:page_id/revisions/:id(.:format)                                                                     comfy/admin/cms/revisions/page#show
#               toggle_branch_comfy_admin_cms_site_page GET                                          /admin/cms/sites/:site_id/pages/:id/toggle_branch(.:format)                                                                          comfy/admin/cms/pages#toggle_branch
#  form_fragments_comfy_admin_cms_site_page_translation GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:id/form_fragments(.:format)                                                   comfy/admin/cms/translations#form_fragments
# revert_comfy_admin_cms_site_page_translation_revision PATCH                                        /admin/cms/sites/:site_id/pages/:page_id/translations/:translation_id/revisions/:id/revert(.:format)                                 comfy/admin/cms/revisions/translation#revert
#       comfy_admin_cms_site_page_translation_revisions GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:translation_id/revisions(.:format)                                            comfy/admin/cms/revisions/translation#index
#        comfy_admin_cms_site_page_translation_revision GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:translation_id/revisions/:id(.:format)                                        comfy/admin/cms/revisions/translation#show
#                comfy_admin_cms_site_page_translations POST                                         /admin/cms/sites/:site_id/pages/:page_id/translations(.:format)                                                                      comfy/admin/cms/translations#create
#             new_comfy_admin_cms_site_page_translation GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/new(.:format)                                                                  comfy/admin/cms/translations#new
#            edit_comfy_admin_cms_site_page_translation GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:id/edit(.:format)                                                             comfy/admin/cms/translations#edit
#                 comfy_admin_cms_site_page_translation GET                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:id(.:format)                                                                  comfy/admin/cms/translations#show
#                                                       PATCH                                        /admin/cms/sites/:site_id/pages/:page_id/translations/:id(.:format)                                                                  comfy/admin/cms/translations#update
#                                                       PUT                                          /admin/cms/sites/:site_id/pages/:page_id/translations/:id(.:format)                                                                  comfy/admin/cms/translations#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/pages/:page_id/translations/:id(.:format)                                                                  comfy/admin/cms/translations#destroy
#                            comfy_admin_cms_site_pages GET                                          /admin/cms/sites/:site_id/pages(.:format)                                                                                            comfy/admin/cms/pages#index
#                                                       POST                                         /admin/cms/sites/:site_id/pages(.:format)                                                                                            comfy/admin/cms/pages#create
#                         new_comfy_admin_cms_site_page GET                                          /admin/cms/sites/:site_id/pages/new(.:format)                                                                                        comfy/admin/cms/pages#new
#                        edit_comfy_admin_cms_site_page GET                                          /admin/cms/sites/:site_id/pages/:id/edit(.:format)                                                                                   comfy/admin/cms/pages#edit
#                             comfy_admin_cms_site_page PATCH                                        /admin/cms/sites/:site_id/pages/:id(.:format)                                                                                        comfy/admin/cms/pages#update
#                                                       PUT                                          /admin/cms/sites/:site_id/pages/:id(.:format)                                                                                        comfy/admin/cms/pages#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/pages/:id(.:format)                                                                                        comfy/admin/cms/pages#destroy
#                    reorder_comfy_admin_cms_site_files PUT                                          /admin/cms/sites/:site_id/files/reorder(.:format)                                                                                    comfy/admin/cms/files#reorder
#                            comfy_admin_cms_site_files GET                                          /admin/cms/sites/:site_id/files(.:format)                                                                                            comfy/admin/cms/files#index
#                                                       POST                                         /admin/cms/sites/:site_id/files(.:format)                                                                                            comfy/admin/cms/files#create
#                         new_comfy_admin_cms_site_file GET                                          /admin/cms/sites/:site_id/files/new(.:format)                                                                                        comfy/admin/cms/files#new
#                        edit_comfy_admin_cms_site_file GET                                          /admin/cms/sites/:site_id/files/:id/edit(.:format)                                                                                   comfy/admin/cms/files#edit
#                             comfy_admin_cms_site_file PATCH                                        /admin/cms/sites/:site_id/files/:id(.:format)                                                                                        comfy/admin/cms/files#update
#                                                       PUT                                          /admin/cms/sites/:site_id/files/:id(.:format)                                                                                        comfy/admin/cms/files#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/files/:id(.:format)                                                                                        comfy/admin/cms/files#destroy
#                  reorder_comfy_admin_cms_site_layouts PUT                                          /admin/cms/sites/:site_id/layouts/reorder(.:format)                                                                                  comfy/admin/cms/layouts#reorder
#           revert_comfy_admin_cms_site_layout_revision PATCH                                        /admin/cms/sites/:site_id/layouts/:layout_id/revisions/:id/revert(.:format)                                                          comfy/admin/cms/revisions/layout#revert
#                 comfy_admin_cms_site_layout_revisions GET                                          /admin/cms/sites/:site_id/layouts/:layout_id/revisions(.:format)                                                                     comfy/admin/cms/revisions/layout#index
#                  comfy_admin_cms_site_layout_revision GET                                          /admin/cms/sites/:site_id/layouts/:layout_id/revisions/:id(.:format)                                                                 comfy/admin/cms/revisions/layout#show
#                          comfy_admin_cms_site_layouts GET                                          /admin/cms/sites/:site_id/layouts(.:format)                                                                                          comfy/admin/cms/layouts#index
#                                                       POST                                         /admin/cms/sites/:site_id/layouts(.:format)                                                                                          comfy/admin/cms/layouts#create
#                       new_comfy_admin_cms_site_layout GET                                          /admin/cms/sites/:site_id/layouts/new(.:format)                                                                                      comfy/admin/cms/layouts#new
#                      edit_comfy_admin_cms_site_layout GET                                          /admin/cms/sites/:site_id/layouts/:id/edit(.:format)                                                                                 comfy/admin/cms/layouts#edit
#                           comfy_admin_cms_site_layout PATCH                                        /admin/cms/sites/:site_id/layouts/:id(.:format)                                                                                      comfy/admin/cms/layouts#update
#                                                       PUT                                          /admin/cms/sites/:site_id/layouts/:id(.:format)                                                                                      comfy/admin/cms/layouts#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/layouts/:id(.:format)                                                                                      comfy/admin/cms/layouts#destroy
#                 reorder_comfy_admin_cms_site_snippets PUT                                          /admin/cms/sites/:site_id/snippets/reorder(.:format)                                                                                 comfy/admin/cms/snippets#reorder
#          revert_comfy_admin_cms_site_snippet_revision PATCH                                        /admin/cms/sites/:site_id/snippets/:snippet_id/revisions/:id/revert(.:format)                                                        comfy/admin/cms/revisions/snippet#revert
#                comfy_admin_cms_site_snippet_revisions GET                                          /admin/cms/sites/:site_id/snippets/:snippet_id/revisions(.:format)                                                                   comfy/admin/cms/revisions/snippet#index
#                 comfy_admin_cms_site_snippet_revision GET                                          /admin/cms/sites/:site_id/snippets/:snippet_id/revisions/:id(.:format)                                                               comfy/admin/cms/revisions/snippet#show
#                         comfy_admin_cms_site_snippets GET                                          /admin/cms/sites/:site_id/snippets(.:format)                                                                                         comfy/admin/cms/snippets#index
#                                                       POST                                         /admin/cms/sites/:site_id/snippets(.:format)                                                                                         comfy/admin/cms/snippets#create
#                      new_comfy_admin_cms_site_snippet GET                                          /admin/cms/sites/:site_id/snippets/new(.:format)                                                                                     comfy/admin/cms/snippets#new
#                     edit_comfy_admin_cms_site_snippet GET                                          /admin/cms/sites/:site_id/snippets/:id/edit(.:format)                                                                                comfy/admin/cms/snippets#edit
#                          comfy_admin_cms_site_snippet PATCH                                        /admin/cms/sites/:site_id/snippets/:id(.:format)                                                                                     comfy/admin/cms/snippets#update
#                                                       PUT                                          /admin/cms/sites/:site_id/snippets/:id(.:format)                                                                                     comfy/admin/cms/snippets#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/snippets/:id(.:format)                                                                                     comfy/admin/cms/snippets#destroy
#                       comfy_admin_cms_site_categories GET                                          /admin/cms/sites/:site_id/categories(.:format)                                                                                       comfy/admin/cms/categories#index
#                                                       POST                                         /admin/cms/sites/:site_id/categories(.:format)                                                                                       comfy/admin/cms/categories#create
#                     new_comfy_admin_cms_site_category GET                                          /admin/cms/sites/:site_id/categories/new(.:format)                                                                                   comfy/admin/cms/categories#new
#                    edit_comfy_admin_cms_site_category GET                                          /admin/cms/sites/:site_id/categories/:id/edit(.:format)                                                                              comfy/admin/cms/categories#edit
#                         comfy_admin_cms_site_category PATCH                                        /admin/cms/sites/:site_id/categories/:id(.:format)                                                                                   comfy/admin/cms/categories#update
#                                                       PUT                                          /admin/cms/sites/:site_id/categories/:id(.:format)                                                                                   comfy/admin/cms/categories#update
#                                                       DELETE                                       /admin/cms/sites/:site_id/categories/:id(.:format)                                                                                   comfy/admin/cms/categories#destroy
#                                 comfy_admin_cms_sites GET                                          /admin/cms/sites(.:format)                                                                                                           comfy/admin/cms/sites#index
#                                                       POST                                         /admin/cms/sites(.:format)                                                                                                           comfy/admin/cms/sites#create
#                              new_comfy_admin_cms_site GET                                          /admin/cms/sites/new(.:format)                                                                                                       comfy/admin/cms/sites#new
#                             edit_comfy_admin_cms_site GET                                          /admin/cms/sites/:id/edit(.:format)                                                                                                  comfy/admin/cms/sites#edit
#                                  comfy_admin_cms_site PATCH                                        /admin/cms/sites/:id(.:format)                                                                                                       comfy/admin/cms/sites#update
#                                                       PUT                                          /admin/cms/sites/:id(.:format)                                                                                                       comfy/admin/cms/sites#update
#                                                       DELETE                                       /admin/cms/sites/:id(.:format)                                                                                                       comfy/admin/cms/sites#destroy
#                                  comfy_cms_render_css GET                                          /cms/cms-css/:site_id/:identifier(/:cache_buster)(.:format)                                                                          comfy/cms/assets#render_css
#                                   comfy_cms_render_js GET                                          /cms/cms-js/:site_id/:identifier(/:cache_buster)(.:format)                                                                           comfy/cms/assets#render_js
#                                 comfy_cms_render_page GET                                          /cms(/*cms_path)(.:format)                                                                                                           comfy/cms/content#show
#                                                       GET|HEAD|POST|PUT|DELETE|OPTIONS|TRACE|PATCH /errors/:name(.:format)                                                                                                              errors#show
#                                                       GET|HEAD|POST|PUT|DELETE|OPTIONS|TRACE|PATCH /*requested_route(.:format)                                                                                                          errors#route_error
#                         rails_postmark_inbound_emails POST                                         /rails/action_mailbox/postmark/inbound_emails(.:format)                                                                              action_mailbox/ingresses/postmark/inbound_emails#create
#                            rails_relay_inbound_emails POST                                         /rails/action_mailbox/relay/inbound_emails(.:format)                                                                                 action_mailbox/ingresses/relay/inbound_emails#create
#                         rails_sendgrid_inbound_emails POST                                         /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                                                              action_mailbox/ingresses/sendgrid/inbound_emails#create
#                   rails_mandrill_inbound_health_check GET                                          /rails/action_mailbox/mandrill/inbound_emails(.:format)                                                                              action_mailbox/ingresses/mandrill/inbound_emails#health_check
#                         rails_mandrill_inbound_emails POST                                         /rails/action_mailbox/mandrill/inbound_emails(.:format)                                                                              action_mailbox/ingresses/mandrill/inbound_emails#create
#                          rails_mailgun_inbound_emails POST                                         /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                                                          action_mailbox/ingresses/mailgun/inbound_emails#create
#                        rails_conductor_inbound_emails GET                                          /rails/conductor/action_mailbox/inbound_emails(.:format)                                                                             rails/conductor/action_mailbox/inbound_emails#index
#                                                       POST                                         /rails/conductor/action_mailbox/inbound_emails(.:format)                                                                             rails/conductor/action_mailbox/inbound_emails#create
#                     new_rails_conductor_inbound_email GET                                          /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                                                         rails/conductor/action_mailbox/inbound_emails#new
#                    edit_rails_conductor_inbound_email GET                                          /rails/conductor/action_mailbox/inbound_emails/:id/edit(.:format)                                                                    rails/conductor/action_mailbox/inbound_emails#edit
#                         rails_conductor_inbound_email GET                                          /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                                                         rails/conductor/action_mailbox/inbound_emails#show
#                                                       PATCH                                        /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                                                         rails/conductor/action_mailbox/inbound_emails#update
#                                                       PUT                                          /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                                                         rails/conductor/action_mailbox/inbound_emails#update
#                                                       DELETE                                       /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                                                         rails/conductor/action_mailbox/inbound_emails#destroy
#              new_rails_conductor_inbound_email_source GET                                          /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                                                                 rails/conductor/action_mailbox/inbound_emails/sources#new
#                 rails_conductor_inbound_email_sources POST                                         /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                                                     rails/conductor/action_mailbox/inbound_emails/sources#create
#                 rails_conductor_inbound_email_reroute POST                                         /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                                                                  rails/conductor/action_mailbox/reroutes#create
#              rails_conductor_inbound_email_incinerate POST                                         /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                                                               rails/conductor/action_mailbox/incinerates#create
#
# Routes for Rswag::Ui::Engine:
#
#
# Routes for Rswag::Api::Engine:

require 'resque/server'

# A constraint that checks if the invocable action parameter exists as
# a method on the controller in the form of `invoke_{action}`.
# Most useful in making sure action invocations are not matched instead of
# nested resources.
class InvocableConstraint
  def initialize(except)
    except ||= []
    @except = except.map(&:downcase)
  end

  def matches?(request)
    action = request.params[:invoke_action]
    return false if action.blank?

    @except.exclude?(action.downcase)
    # Alternate idea: only match if the controller has the action.
    # Unfortunately, this means we can't do good error reporting and explain what actions are
    # available because when the constraint rejects the route we moved on and fail on our
    # generic not found route which has no information about available actions.
    #controller = request.controller_class
    #invocable_actions = controller.invocable_actions
    #invocable_actions.include?(action)
  end
end

Rails.application.routes.draw do
  # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Filtering
  concern :filterable do
    match 'filter', via: [:get, :post], on: :collection, defaults: { format: 'json' }
  end

  # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Capabilties
  concern :capable do
    get 'capabilities', on: :collection, defaults: { format: 'json' }
    get 'capabilities', on: :member, defaults: { format: 'json' }
  end

  # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Actions
  # Use `do_not_match_as_invocable` to prevent a route from being matched as an invocable action.
  concern :invocable do |options|
    match ':invoke_action',
      via: [:post, :put],
      on: :member,
      defaults: { format: 'json' },
      action: :invoke,
      constraints: InvocableConstraint.new(options[:do_not_match_as_invocable]),
      as: 'invoke'
  end

  # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Stats
  concern :statistical do
    match 'stats', via: [:get, :post], on: :collection, defaults: { format: 'json' }
  end

  concern :archivable do
    # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Archiving
    # both of these are 'action like' even though they do call `:invoke` on the controller
    # permanent delete
    match 'destroy',
      via: [:post, :delete],
      on: :member,
      defaults: { format: 'json' },
      action: :destroy_permanently,
      as: 'destroy_permanently'
    # recover from soft delete
    post 'recover', on: :member, defaults: { format: 'json' }
  end

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
  # user list and user profile
  resources :user_accounts, only: [:index, :show, :edit, :update], constraints: { id: /[0-9]+/ },
    concerns: [:filterable] do
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

  # Internal routes
  post '/internal/sftpgo/hook' => 'internal/sftpgo#hook', defaults: { format: 'json' }

  # Resource Routes
  # ===============

  resources :bookmarks, except: [:edit], concerns: [:filterable]

  # routes used by workers:
  # login: /security/sign_in
  # audio_recording_update: /audio_recordings/:id

  # routes used by harvester:
  # login: /security
  # audio_recording: /audio_recordings/:id
  # audio_recording_create: /projects/:project_id/sites/:site_id/audio_recordings
  # audio_recording_uploader: /projects/:project_id/sites/:site_id/audio_recordings/check_uploader/:uploader_id
  # audio_recording_update_status: /audio_recordings/:id/update_status
  match 'projects/:project_id/harvests/:harvest_id/items/filter' => 'harvest_items#filter', via: [:get, :post],
    defaults: { format: 'json' }

  # routes for projects and nested resources
  resources :projects, concerns: [:filterable] do
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
    resources :permissions, except: [:edit, :index], defaults: { format: 'json' }, concerns: [:filterable]
    # HTML project site item
    resources :sites, except: [:index], concerns: [:filterable] do
      member do
        get :upload_instructions
        get 'harvest' => 'sites#harvest'
      end
      # API project site recording check_uploader
      resources :audio_recordings, only: [:create, :new], defaults: { format: 'json' }, concerns: [:filterable] do
        collection do
          get 'check_uploader/:uploader_id', defaults: { format: 'json' }, action: :check_uploader
        end
      end
    end
    # API project sites list
    resources :sites, only: [:index], defaults: { format: 'json' }, concerns: [:filterable]

    # API only: regions
    resources :regions, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable]

    # API only: harvests
    resources :harvests, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable] do
      get 'items(/*path)' => 'harvest_items#index', defaults: { format: 'json' }, format: false
    end
  end

  # route for AnalysisJobsItems results (indexed by analysis_jobs_items_id)
  match 'analysis_jobs/:analysis_job_id/results/(*results_path)' => 'analysis_jobs_results#results',
    defaults: { format: 'json' }, as: :analysis_jobs_results_results, via: [:get, :head], format: false, action: 'results'
  # route for AnalysisJobsItems artifacts (indexed by project hierarchy)
  match 'analysis_jobs/:analysis_job_id/artifacts/(*results_path)' => 'analysis_jobs_results#artifacts',
    defaults: { format: 'json' }, as: :analysis_jobs_results_artifacts, via: [:get, :head], format: false, action: 'artifacts'

  # API only for analysis_jobs, analysis_jobs_items, and saved_searches
  resources :analysis_jobs, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable] do
    concerns :invocable, do_not_match_as_invocable: ['items']
    resources 'items', controller: 'analysis_jobs_items', only: [:show, :index],
      defaults: { format: 'json' }, concerns: [:filterable, :invocable]
  end

  resources :saved_searches, except: [:edit, :update], defaults: { format: 'json' }, concerns: [:filterable]

  namespace :audio_recordings do
    match 'downloader' => 'downloader#index', via: [:get, :post], defaults: { format: 'json' }
  end

  match 'taggings/filter' => 'taggings#filter', via: [:get, :post], defaults: { format: 'json' }

  # API audio recording item
  resources :audio_recordings, only: [:index, :show, :new, :update], defaults: { format: 'json' },
    concerns: [:filterable] do
    match 'media.:format' => 'media#show', defaults: { format: 'json' }, as: :media, via: [:get, :head]
    scope defaults: { format: false } do
      match 'original' => 'media#original', as: :media_original, via: [:get, :head]
    end
    resources :audio_events, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable] do
      collection do
        get 'download', defaults: { format: 'csv' }
      end
      resources :tags, only: [:index], defaults: { format: 'json' }
      resources :taggings, except: [:edit], defaults: { format: 'json' }
      resources :verifications, only: [:index, :show], defaults: { format: 'json' }, concerns: [:filterable]
    end
  end

  # API update status for audio_recording item, separate so it has :id and not :audio_recording_id
  resources :audio_recordings, only: [], defaults: { format: 'json' }, shallow: true, concerns: [:filterable] do
    member do
      put 'update_status' # for when harvester has moved a file to the correct location
    end
  end

  # API tags
  resources :tags, only: [:index, :show, :create, :new], defaults: { format: 'json' }, concerns: [:filterable]

  # API verifications
  resources :verifications, except: [:edit],
    as: 'shallow_verifications',
    defaults: { format: 'json' },
    concerns: [:filterable]

  # API audio_event create
  resources :audio_events, only: [], defaults: { format: 'json' }, concerns: [:filterable] do
    resources :audio_event_comments, except: [:edit], defaults: { format: 'json' }, path: :comments, as: :comments,
      concerns: [:filterable]
  end

  resources :provenances, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable]

  resources :audio_event_imports, except: [:edit], defaults: { format: 'json' }, concerns: [:filterable, :archivable] do
    # immutable
    resources 'files', controller: 'audio_event_import_files', except: [:edit, :update], defaults: { format: 'json' },
      concerns: [:filterable]
  end

  post '/audio_event_reports' => 'audio_event_reports#filter', defaults: { format: 'json' }

  resources :scripts, only: [:index, :show], defaults: { format: 'json' }, concerns: [:filterable]

  # taggings made by a user
  get '/user_accounts/:user_id/taggings' => 'taggings#user_index', as: :user_taggings, defaults: { format: 'json' }

  # audio event csv download routes
  get '/projects/:project_id/audio_events/download' => 'audio_events#download',
    defaults: { format: 'csv' }, as: :download_project_audio_events
  get '/projects/:project_id/sites/:site_id/audio_events/download' => 'audio_events#download',
    defaults: { format: 'csv' }, as: :download_site_audio_events
  get '/user_accounts/:user_id/audio_events/download' => 'audio_events#download',
    defaults: { format: 'csv' }, as: :download_user_audio_events

  # path for orphaned sites
  get 'sites/orphans' => 'sites#orphans'
  match 'sites/orphans/filter' => 'sites#orphans', via: [:get, :post], defaults: { format: 'json' }

  # shallow path to sites
  resources :sites, except: [:edit], defaults: { format: 'json' }, as: 'shallow_site', concerns: [:filterable]

  # shallow regions
  resources :regions, except: [:edit], defaults: { format: 'json' }, as: 'shallow_region', concerns: [:filterable]

  # shallow harvests
  match 'harvests/:harvest_id/items/filter' => 'harvest_items#filter', via: [:get, :post], defaults: { format: 'json' }
  resources :harvests, except: [:edit], defaults: { format: 'json' }, as: 'harvest', concerns: [:filterable] do
    get 'items(/*path)' => 'harvest_items#index', defaults: { format: 'json' }, format: false
  end

  post 'datasets/:dataset_id/progress_events/audio_recordings/:audio_recording_id/start/:start_time_seconds/end/:end_time_seconds' =>
    'progress_events#create_by_dataset_item_params', :constraints => {
      dataset_id: /(\d+|default)/,
      audio_recording_id: /\d+/,
      start_time_seconds: /\d+(\.\d+)?/,
      end_time_seconds: /\d+(\.\d+)?/
    }, defaults: { format: 'json' }

  # datasets, dataset_items
  # AT 2024: these routes are very inconsistent with our conventions, and should be updated/deprecated
  match 'dataset_items/filter' => 'dataset_items#filter', via: [:get, :post], defaults: { format: 'json' }
  match 'datasets/:dataset_id/dataset_items/filter' => 'dataset_items#filter', via: [:get, :post],
    defaults: { format: 'json' }
  get 'datasets/:dataset_id/dataset_items/next_for_me' => 'dataset_items#next_for_me', defaults: { format: 'json' }
  resources :datasets, except: :destroy, defaults: { format: 'json' }, concerns: [:filterable] do
    resources :items, controller: 'dataset_items', defaults: { format: 'json' }, concerns: [:filterable]
  end

  # studies, questions, responses
  put 'responses/:id', to: 'errors#method_not_allowed_error'
  put '/studies/:study_id/responses/:id', to: 'errors#method_not_allowed'
  resources :studies, defaults: { format: 'json' }, concerns: [:filterable]
  resources :questions, defaults: { format: 'json' }, concerns: [:filterable]
  resources :responses, except: :update, defaults: { format: 'json' }, concerns: [:filterable]
  get '/studies/:study_id/questions' => 'questions#index', defaults: { format: 'json' }
  get '/studies/:study_id/responses' => 'responses#index', defaults: { format: 'json' }
  post '/studies/:study_id/questions/:question_id/responses' => 'responses#create', defaults: { format: 'json' }

  # progress events
  resources :progress_events, defaults: { format: 'json' }, concerns: [:filterable]

  # route to the home page of site
  root to: 'public#index'

  # site status API
  get '/status/' => 'status#index', defaults: { format: 'json' }
  get '/website_status/' => 'public#website_status'
  get '/stats/' => 'stats#index', defaults: { format: 'json' }

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
    require Rails.root.join('lib/gems/baw-workers/lib/resque/status_server').to_s
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

  # enable CORS preflight requests
  match '*requested_route', to: 'public#cors_preflight', via: :options

  # exceptions testing route - only available in test env
  if ENV.fetch('RAILS_ENV', nil) == 'test'
    # via: :all seems to not work any more >:(
    match '/test_exceptions', to: 'errors#test_exceptions',
      via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]
  end

  comfy_route_cms_admin(path: '/admin/cms')
  # Ensure that this route is defined last
  comfy_route :cms, path: '/cms'

  # routes directly to error pages
  match '/errors/:name', to: 'errors#show', via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]

  # for error pages - must be last
  match '*requested_route', to: 'errors#route_error', via: [:get, :head, :post, :put, :delete, :options, :trace, :patch]
end
