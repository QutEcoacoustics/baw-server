class RenameJobs < ActiveRecord::Migration
  def change

    reversible do |direction|
      direction.up do
        # remove foreign keys, rename table, then add foreign keys with new names
        remove_foreign_key "jobs", "saved_searches"
        remove_foreign_key "jobs", "scripts"

        remove_foreign_key "jobs", column: "creator_id"
        remove_foreign_key "jobs", column: "deleter_id"
        remove_foreign_key "jobs", column: "updater_id"

        rename_table :jobs, :analysis_jobs

        add_foreign_key "analysis_jobs", "saved_searches", name: "analysis_jobs_saved_search_id_fk"
        add_foreign_key "analysis_jobs", "scripts", name: "analysis_jobs_script_id_fk"

        add_foreign_key "analysis_jobs", "users", column: "creator_id", name: "analysis_jobs_creator_id_fk"
        add_foreign_key "analysis_jobs", "users", column: "deleter_id", name: "analysis_jobs_deleter_id_fk"
        add_foreign_key "analysis_jobs", "users", column: "updater_id", name: "analysis_jobs_updater_id_fk"
      end

      direction.down do
        # remove foreign keys, rename table, then add foreign keys with new names
        remove_foreign_key "analysis_jobs", "saved_searches"
        remove_foreign_key "analysis_jobs", "scripts"

        remove_foreign_key "analysis_jobs", column: "creator_id"
        remove_foreign_key "analysis_jobs", column: "deleter_id"
        remove_foreign_key "analysis_jobs", column: "updater_id"

        rename_table :jobs, :analysis_jobs

        add_foreign_key "jobs", "saved_searches", name: "jobs_saved_search_id_fk"
        add_foreign_key "jobs", "scripts", name: "jobs_script_id_fk"

        add_foreign_key "jobs", "users", column: "creator_id", name: "jobs_creator_id_fk"
        add_foreign_key "jobs", "users", column: "deleter_id", name: "jobs_deleter_id_fk"
        add_foreign_key "jobs", "users", column: "updater_id", name: "jobs_updater_id_fk"
      end
    end
  end
end
