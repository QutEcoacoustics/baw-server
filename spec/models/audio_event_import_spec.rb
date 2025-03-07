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
describe AudioEventImport do
  subject { build(:audio_event_import) }

  it 'has a valid factory' do
    expect(create(:audio_event_import)).to be_valid
  end

  it { is_expected.to belong_to(:creator).inverse_of(:created_audio_event_imports) }
  it { is_expected.to belong_to(:updater).inverse_of(:updated_audio_event_imports).optional }
  it { is_expected.to belong_to(:deleter).inverse_of(:deleted_audio_event_imports).optional }

  it { is_expected.to have_many(:audio_event_import_files) }
  it { is_expected.to belong_to(:analysis_job).optional }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_least(2) }
end
