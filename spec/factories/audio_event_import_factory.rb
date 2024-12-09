# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_imports
#
#  id                                                     :bigint           not null, primary key
#  deleted_at                                             :datetime
#  description                                            :text
#  name                                                   :string
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#  analysis_job_id(Analysis job that created this import) :integer
#  creator_id                                             :integer          not null
#  deleter_id                                             :integer
#  updater_id                                             :integer
#
# Indexes
#
#  index_audio_event_imports_on_analysis_job_id  (analysis_job_id)
#
# Foreign Keys
#
#  audio_event_imports_creator_id_fk  (creator_id => users.id)
#  audio_event_imports_deleter_id_fk  (deleter_id => users.id)
#  audio_event_imports_updater_id_fk  (updater_id => users.id)
#  fk_rails_...                       (analysis_job_id => analysis_jobs.id)
#
FactoryBot.define do
  factory :audio_event_import do
    sequence(:name) { |n| "import name #{n}" }
    sequence(:description) { |n| "import **description** #{n}" }

    creator
    updater
  end
end
