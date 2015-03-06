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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150306224910) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audio_event_comments", force: :cascade do |t|
    t.integer  "audio_event_id",             null: false
    t.text     "comment",                    null: false
    t.string   "flag",           limit: 255
    t.text     "flag_explain"
    t.integer  "flagger_id"
    t.datetime "flagged_at"
    t.integer  "creator_id",                 null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "audio_events", force: :cascade do |t|
    t.integer  "audio_recording_id",                                            null: false
    t.decimal  "start_time_seconds",   precision: 10, scale: 4,                 null: false
    t.decimal  "end_time_seconds",     precision: 10, scale: 4
    t.decimal  "low_frequency_hertz",  precision: 10, scale: 4,                 null: false
    t.decimal  "high_frequency_hertz", precision: 10, scale: 4
    t.boolean  "is_reference",                                  default: false, null: false
    t.integer  "creator_id",                                                    null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
  end

  create_table "audio_events_tags", force: :cascade do |t|
    t.integer  "audio_event_id", null: false
    t.integer  "tag_id",         null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "creator_id",     null: false
    t.integer  "updater_id"
  end

  add_index "audio_events_tags", ["audio_event_id", "tag_id"], name: "index_audio_events_tags_on_audio_event_id_and_tag_id", unique: true, using: :btree

  create_table "audio_recordings", force: :cascade do |t|
    t.string   "uuid",                limit: 36,                                           null: false
    t.integer  "uploader_id",                                                              null: false
    t.datetime "recorded_date",                                                            null: false
    t.integer  "site_id",                                                                  null: false
    t.decimal  "duration_seconds",                precision: 10, scale: 4,                 null: false
    t.integer  "sample_rate_hertz"
    t.integer  "channels"
    t.integer  "bit_rate_bps"
    t.string   "media_type",          limit: 255,                                          null: false
    t.integer  "data_length_bytes",   limit: 8,                                            null: false
    t.string   "file_hash",           limit: 524,                                          null: false
    t.string   "status",              limit: 255,                          default: "new"
    t.text     "notes"
    t.integer  "creator_id",                                                               null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "created_at",                                                               null: false
    t.datetime "updated_at",                                                               null: false
    t.datetime "deleted_at"
    t.string   "original_file_name",  limit: 255
    t.string   "recorded_utc_offset", limit: 20
  end

  add_index "audio_recordings", ["created_at", "updated_at"], name: "audio_recordings_created_updated_at", using: :btree
  add_index "audio_recordings", ["site_id"], name: "index_audio_recordings_on_site_id", using: :btree

  create_table "bookmarks", force: :cascade do |t|
    t.integer  "audio_recording_id"
    t.decimal  "offset_seconds",                 precision: 10, scale: 4
    t.string   "name",               limit: 255
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.integer  "creator_id",                                              null: false
    t.integer  "updater_id"
    t.text     "description"
    t.string   "category",           limit: 255
  end

  create_table "datasets", force: :cascade do |t|
    t.string   "name",                        limit: 255, null: false
    t.time     "start_time"
    t.time     "end_time"
    t.date     "start_date"
    t.date     "end_date"
    t.string   "filters",                     limit: 255
    t.integer  "number_of_samples"
    t.integer  "number_of_tags"
    t.string   "types_of_tags",               limit: 255
    t.text     "description"
    t.integer  "creator_id",                              null: false
    t.integer  "updater_id"
    t.integer  "project_id",                              null: false
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.string   "dataset_result_file_name",    limit: 255
    t.string   "dataset_result_content_type", limit: 255
    t.integer  "dataset_result_file_size"
    t.datetime "dataset_result_updated_at"
    t.text     "tag_text_filters"
  end

  create_table "datasets_sites", id: false, force: :cascade do |t|
    t.integer "dataset_id", null: false
    t.integer "site_id",    null: false
  end

  create_table "jobs", force: :cascade do |t|
    t.string   "name",            limit: 255, null: false
    t.string   "annotation_name", limit: 255
    t.text     "script_settings"
    t.integer  "dataset_id",                  null: false
    t.integer  "script_id",                   null: false
    t.integer  "creator_id",                  null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.text     "description"
  end

  create_table "permissions", force: :cascade do |t|
    t.integer  "creator_id",                                 null: false
    t.string   "level",          limit: 255,                 null: false
    t.integer  "project_id",                                 null: false
    t.integer  "user_id"
    t.integer  "updater_id"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.boolean  "logged_in_user",             default: false, null: false
    t.boolean  "anonymous_user",             default: false, null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string   "name",               limit: 255, null: false
    t.text     "description"
    t.string   "urn",                limit: 255
    t.text     "notes"
    t.integer  "creator_id",                     null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.string   "image_file_name",    limit: 255
    t.string   "image_content_type", limit: 255
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "projects_sites", id: false, force: :cascade do |t|
    t.integer "project_id", null: false
    t.integer "site_id",    null: false
  end

  create_table "scripts", force: :cascade do |t|
    t.string   "name",                       limit: 255,                                         null: false
    t.string   "description",                limit: 255
    t.text     "notes"
    t.string   "settings_file_file_name",    limit: 255
    t.string   "settings_file_content_type", limit: 255
    t.integer  "settings_file_file_size"
    t.datetime "settings_file_updated_at"
    t.string   "data_file_file_name",        limit: 255
    t.string   "data_file_content_type",     limit: 255
    t.integer  "data_file_file_size"
    t.datetime "data_file_updated_at"
    t.string   "analysis_identifier",        limit: 255,                                         null: false
    t.decimal  "version",                                precision: 4, scale: 2, default: 0.1,   null: false
    t.boolean  "verified",                                                       default: false
    t.integer  "updated_by_script_id"
    t.integer  "creator_id",                                                                     null: false
    t.datetime "created_at",                                                                     null: false
  end

  create_table "sites", force: :cascade do |t|
    t.string   "name",               limit: 255,                         null: false
    t.decimal  "longitude",                      precision: 9, scale: 6
    t.decimal  "latitude",                       precision: 9, scale: 6
    t.text     "notes"
    t.integer  "creator_id",                                             null: false
    t.integer  "updater_id"
    t.integer  "deleter_id"
    t.datetime "deleted_at"
    t.string   "image_file_name",    limit: 255
    t.string   "image_content_type", limit: 255
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.text     "description"
    t.string   "tzinfo_tz",          limit: 255
    t.string   "rails_tz",           limit: 255
  end

  create_table "tags", force: :cascade do |t|
    t.string   "text",         limit: 255,                     null: false
    t.boolean  "is_taxanomic",             default: false,     null: false
    t.string   "type_of_tag",  limit: 255, default: "general", null: false
    t.boolean  "retired",                  default: false,     null: false
    t.text     "notes"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.integer  "creator_id",                                   null: false
    t.integer  "updater_id"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255,             null: false
    t.string   "user_name",              limit: 255,             null: false
    t.string   "encrypted_password",     limit: 255,             null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.string   "confirmation_token",     limit: 255
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email",      limit: 255
    t.integer  "failed_attempts",                    default: 0
    t.string   "unlock_token",           limit: 255
    t.datetime "locked_at"
    t.string   "authentication_token",   limit: 255
    t.string   "invitation_token",       limit: 255
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "roles_mask"
    t.string   "image_file_name",        limit: 255
    t.string   "image_content_type",     limit: 255
    t.integer  "image_file_size"
    t.datetime "image_updated_at"
    t.text     "preferences"
    t.string   "tzinfo_tz",              limit: 255
    t.string   "rails_tz",               limit: 255
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree
  add_index "users", ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true, using: :btree
  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["user_name"], name: "users_user_name_unique", unique: true, using: :btree

end
