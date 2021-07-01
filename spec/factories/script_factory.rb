# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                             :integer          not null, primary key
#  analysis_action_params         :json
#  analysis_identifier            :string           not null
#  description                    :string
#  executable_command             :text             not null
#  executable_settings            :text             not null
#  executable_settings_media_type :string(255)      default("text/plain")
#  name                           :string           not null
#  verified                       :boolean          default(FALSE)
#  version                        :decimal(4, 2)    default(0.1), not null
#  created_at                     :datetime         not null
#  creator_id                     :integer          not null
#  group_id                       :integer
#
# Indexes
#
#  index_scripts_on_creator_id  (creator_id)
#  index_scripts_on_group_id    (group_id)
#
# Foreign Keys
#
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#
include ActionDispatch::TestProcess

FactoryBot.define do
  factory :script do
    sequence(:name) { |n| "script name #{n}" }
    sequence(:description) { |n| "script description #{n}" }
    sequence(:analysis_identifier) { |n| "script machine identifier #{n}" }
    sequence(:version) { |n| n * 0.01 }
    sequence(:executable_command) { |n| "executable command #{n}" }
    sequence(:executable_settings) { |n| "executable settings #{n}" }
    sequence(:executable_settings_media_type) { |_n| 'text/plain' }
    sequence(:analysis_action_params) do |n|
      {
        file_executable: './AnalysisPrograms/AnalysisPrograms.exe',
        copy_paths: [
          './programs/AnalysisPrograms/Logs/log.txt'
        ],
        sub_folders: [],
        custom_setting: n
      }
    end

    creator

    trait :verified do
      verified { true }
    end
  end
end
