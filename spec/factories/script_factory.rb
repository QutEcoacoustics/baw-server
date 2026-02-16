# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                                                                                                                   :integer          not null, primary key
#  analysis_identifier(a unique identifier for this script in the analysis system, used in directory names. [-a-z0-0_]) :string           not null
#  description                                                                                                          :string
#  event_import_glob(Glob pattern to match result files that should be imported as audio events)                        :string
#  event_import_include_top(Limit import to the top N results per tag per file)                                         :integer
#  event_import_include_top_per(Apply top filtering per this interval, in seconds)                                      :integer
#  event_import_minimum_score(Minimum score threshold for importing events, if any)                                     :decimal(, )
#  executable_command                                                                                                   :text             not null
#  executable_settings                                                                                                  :text
#  executable_settings_media_type                                                                                       :string(255)      default("text/plain")
#  executable_settings_name                                                                                             :string
#  name                                                                                                                 :string           not null
#  resources(Resources required by this script in the PBS format.)                                                      :jsonb
#  verified                                                                                                             :boolean          default(FALSE)
#  version(Version of this script - not the version of program the script runs!)                                        :integer          default(1), not null
#  created_at                                                                                                           :datetime         not null
#  creator_id                                                                                                           :integer          not null
#  group_id                                                                                                             :integer
#  provenance_id                                                                                                        :integer
#
# Indexes
#
#  index_scripts_on_creator_id     (creator_id)
#  index_scripts_on_group_id       (group_id)
#  index_scripts_on_provenance_id  (provenance_id)
#
# Foreign Keys
#
#  fk_rails_...           (provenance_id => provenances.id)
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#

FactoryBot.define do
  factory :script do
    sequence(:name) { |n| "script name #{n}" }
    sequence(:description) { |n| "script description #{n}" }
    sequence(:analysis_identifier) { |n| "script_name_#{n}" }
    sequence(:version) { |n| n }
    sequence(:executable_command) do |n|
      "echo 'some_binary --source {source_dir} --config {config_dir} --temp-dir {temp_dir} --output {output_dir}  #{n}'"
    end
    sequence(:executable_settings) { |n| "executable settings #{n}" }
    sequence(:executable_settings_media_type) { |_n| 'text/plain' }
    sequence(:executable_settings_name) { |_n| 'config.txt' }

    event_import_glob { '*.csv' }

    resources do
      {
        'ncpus' => 1,
        'mem' => 1_000_000
      }
    end

    creator
    provenance

    trait :verified do
      verified { true }
    end
  end
end
