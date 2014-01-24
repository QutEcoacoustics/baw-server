# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20140123030923) do

  create_table "audio_events", :force => true do |t|
    t.integer  "audio_recording_id",                                                     :null => false
    t.decimal  "start_time_seconds",   :precision => 10, :scale => 4,                    :null => false
    t.decimal  "end_time_seconds",     :precision => 10, :scale => 4
    t.decimal  "low_frequency_hertz",  :precision => 10, :scale => 4,                    :null => false
    t.decimal  "high_frequency_hertz", :precision => 10, :scale => 4
    t.boolean  "is_reference",                                        :default => false, :null => false
    t.integer  "creator_id",                                                             :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at",                                                             :null => false
    t.datetime "updated_at",                                                             :null => false
  end

  create_table "audio_events_tags", :force => true do |t|
    t.integer  "audio_event_id", :null => false
    t.integer  "tag_id",         :null => false
    t.datetime "created_at",     :null => false
    t.datetime "updated_at",     :null => false
    t.integer  "creator_id",     :null => false
    t.integer  "updater_id"
  end

  add_index "audio_events_tags", ["audio_event_id", "tag_id"], :name => "index_audio_events_tags_on_audio_event_id_and_tag_id", :unique => true

  create_table "audio_recordings", :force => true do |t|
    t.string   "uuid",               :limit => 36,                                                    :null => false
    t.integer  "uploader_id",                                                                         :null => false
    t.datetime "recorded_date",                                                                       :null => false
    t.integer  "site_id",                                                                             :null => false
    t.decimal  "duration_seconds",                  :precision => 10, :scale => 4,                    :null => false
    t.integer  "sample_rate_hertz"
    t.integer  "channels"
    t.integer  "bit_rate_bps"
    t.string   "media_type",                                                                          :null => false
    t.integer  "data_length_bytes",                                                                   :null => false
    t.string   "file_hash",          :limit => 524,                                                   :null => false
    t.string   "status",                                                           :default => "new"
    t.text     "notes"
    t.integer  "creator_id",                                                                          :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "created_at",                                                                          :null => false
    t.datetime "updated_at",                                                                          :null => false
    t.datetime "deleted_at"
    t.string   "original_file_name"
  end

  create_table "bookmarks", :force => true do |t|
    t.integer  "audio_recording_id"
    t.decimal  "offset_seconds",     :precision => 10, :scale => 4
    t.string   "name"
    t.text     "notes"
    t.datetime "created_at",                                        :null => false
    t.datetime "updated_at",                                        :null => false
    t.integer  "creator_id",                                        :null => false
    t.integer  "updater_id"
  end

  create_table "datasets", :force => true do |t|
    t.string   "processing_status",                                     :null => false
    t.decimal  "total_duration_seconds", :precision => 10, :scale => 4
    t.integer  "audio_recording_count"
    t.datetime "earliest_datetime"
    t.time     "earliest_time_of_day"
    t.datetime "latest_datetime"
    t.time     "latest_time_of_day"
    t.integer  "saved_search_id",                                       :null => false
    t.integer  "creator_id",                                            :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at",                                            :null => false
    t.datetime "updated_at",                                            :null => false
  end

  create_table "jobs", :force => true do |t|
    t.string   "name",            :null => false
    t.string   "annotation_name"
    t.text     "script_settings"
    t.integer  "dataset_id",      :null => false
    t.integer  "script_id",       :null => false
    t.integer  "creator_id",      :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  create_table "permissions", :force => true do |t|
    t.integer  "creator_id", :null => false
    t.string   "level",      :null => false
    t.integer  "project_id", :null => false
    t.integer  "user_id",    :null => false
    t.integer  "updater_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "projects", :force => true do |t|
    t.string   "name",               :null => false
    t.text     "description"
    t.string   "urn"
    t.text     "notes"
    t.integer  "creator_id",         :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
  end

  create_table "projects_sites", :id => false, :force => true do |t|
    t.integer "project_id", :null => false
    t.integer "site_id",    :null => false
  end

  create_table "saved_searches", :force => true do |t|
    t.string   "name",                     :null => false
    t.time     "start_time"
    t.time     "end_time"
    t.date     "start_date"
    t.date     "end_date"
    t.string   "filters"
    t.integer  "number_of_samples"
    t.integer  "number_of_tags"
    t.string   "types_of_tags"
    t.text     "description"
    t.integer  "creator_id",               :null => false
    t.integer  "updater_id"
    t.integer  "project_id",               :null => false
    t.datetime "created_at",               :null => false
    t.datetime "updated_at",               :null => false
    t.text     "tag_text_filters"
    t.string   "auto_generated_identifer"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
  end

  create_table "saved_searches_sites", :id => false, :force => true do |t|
    t.integer "saved_search_id", :null => false
    t.integer "site_id",         :null => false
  end

  create_table "scripts", :force => true do |t|
    t.string   "name",                                                                        :null => false
    t.string   "description"
    t.text     "notes"
    t.string   "settings_file_file_name"
    t.string   "settings_file_content_type"
    t.integer  "settings_file_file_size"
    t.datetime "settings_file_updated_at"
    t.string   "data_file_file_name"
    t.string   "data_file_content_type"
    t.integer  "data_file_file_size"
    t.datetime "data_file_updated_at"
    t.string   "analysis_identifier",                                                         :null => false
    t.decimal  "version",                    :precision => 4, :scale => 2, :default => 0.1,   :null => false
    t.boolean  "verified",                                                 :default => false
    t.integer  "updated_by_script_id"
    t.integer  "creator_id",                                                                  :null => false
    t.datetime "created_at",                                                                  :null => false
  end

  create_table "sites", :force => true do |t|
    t.string   "name",                                             :null => false
    t.decimal  "longitude",          :precision => 9, :scale => 6
    t.decimal  "latitude",           :precision => 9, :scale => 6
    t.text     "notes"
    t.integer  "creator_id",                                       :null => false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at",                                       :null => false
    t.datetime "updated_at",                                       :null => false
  end

  create_table "tags", :force => true do |t|
    t.string   "text",                                :null => false
    t.boolean  "is_taxanomic", :default => false,     :null => false
    t.string   "type_of_tag",  :default => "general", :null => false
    t.boolean  "retired",      :default => false,     :null => false
    t.text     "notes"
    t.datetime "created_at",                          :null => false
    t.datetime "updated_at",                          :null => false
    t.integer  "creator_id",                          :null => false
    t.integer  "updater_id"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "", :null => false
    t.string   "user_name",              :default => "", :null => false
    t.string   "encrypted_password",     :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.integer  "failed_attempts",        :default => 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.string   "authentication_token"
    t.string   "invitation_token"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.integer  "roles_mask"
    t.string   "image_file_name"
    t.string   "image_content_type"
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
  end

  add_index "users", ["authentication_token"], :name => "index_users_on_authentication_token", :unique => true
  add_index "users", ["confirmation_token"], :name => "index_users_on_confirmation_token", :unique => true
  add_index "users", ["email"], :name => "index_users_on_email", :unique => true

end
