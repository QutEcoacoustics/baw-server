# frozen_string_literal: true

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
