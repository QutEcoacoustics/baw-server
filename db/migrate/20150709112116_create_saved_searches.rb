class CreateSavedSearches < ActiveRecord::Migration
  def change

    reversible do |direction|
      direction.up do
        # remove foreign keys for datasets tables
        remove_foreign_key "datasets", column: "creator_id"
        remove_foreign_key "datasets", "projects"
        remove_foreign_key "datasets", column: "updater_id"

        remove_foreign_key "datasets_sites", "datasets"
        remove_foreign_key "datasets_sites", "sites"

        remove_foreign_key "jobs", "datasets"

        # remove reference to datasets from jobs
        remove_column :jobs, :dataset_id
      end

      direction.down do
        add_foreign_key "datasets", "users", column: "creator_id", name: "datasets_creator_id_fk"
        add_foreign_key "datasets", "projects", name: "datasets_project_id_fk"
        add_foreign_key "datasets", "users", column: "updater_id", name: "datasets_updater_id_fk"

        add_foreign_key "datasets_sites", "datasets", name: "datasets_sites_dataset_id_fk"
        add_foreign_key "datasets_sites", "sites", name: "datasets_sites_site_id_fk"

        add_foreign_key "jobs", "datasets", name: "jobs_dataset_id_fk"

        add_column :jobs, :dataset_id, :integer, null: false
      end
    end

    # drop datasets table (with block to be reversible)
    drop_table :datasets do |t|
      t.string "name", null: false
      t.time "start_time"
      t.time "end_time"
      t.date "start_date"
      t.date "end_date"
      t.string "filters"
      t.integer "number_of_samples"
      t.integer "number_of_tags"
      t.string "types_of_tags"
      t.text "description"
      t.integer "creator_id", null: false
      t.integer "updater_id"
      t.integer "project_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "dataset_result_file_name"
      t.string "dataset_result_content_type"
      t.integer "dataset_result_file_size"
      t.datetime "dataset_result_updated_at"
      t.text "tag_text_filters"
    end

    # drop datasets_sites table (with block to be reversible)
    drop_table :datasets_sites, id: false do |t|
      t.integer "dataset_id", null: false
      t.integer "site_id",    null: false
    end

    # add saved_searches table
    create_table :saved_searches do |t|
      t.string :name, null: false, limit: 255
      t.text :description
      t.text :stored_query, null: false

      t.integer :creator_id, null: false
      t.datetime :created_at, null: false
      t.integer :deleter_id
      t.datetime :deleted_at
    end

    # add projects_saved_searches table
    create_table :projects_saved_searches, id: false do |t|
      t.integer :project_id, null: false
      t.integer :saved_search_id, null: false
    end

    # add reference to saved_search from jobs
    add_column :jobs, :saved_search_id, :integer, null: false

    # add foreign keys
    add_foreign_key "saved_searches", "users", column: "creator_id", name: "saved_searches_creator_id_fk"
    add_foreign_key "saved_searches", "users", column: "deleter_id", name: "saved_searches_deleter_id_fk"

    add_foreign_key "projects_saved_searches", "projects", name: "projects_saved_searches_project_id_fk"
    add_foreign_key "projects_saved_searches", "saved_searches", name: "projects_saved_searches_saved_search_id_fk"

    add_foreign_key "jobs", "saved_searches", name: "jobs_saved_search_id_fk"

  end
end
