# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recording_statistics
#
#  analyses_completed_count  :bigint           default(0)
#  bucket                    :tsrange          not null, primary key
#  original_download_count   :bigint           default(0)
#  segment_download_count    :bigint           default(0)
#  segment_download_duration :decimal(, )      default(0.0)
#  audio_recording_id        :bigint           not null, primary key
#
# Indexes
#
#  constraint_baw_audio_recording_statistics_unique        (audio_recording_id,bucket) UNIQUE
#  index_audio_recording_statistics_on_audio_recording_id  (audio_recording_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#

RSpec.describe Statistics::AudioRecordingStatistics do
  subject { build(:audio_recording_statistics) }

  it 'has a valid factory' do
    expect(create(:audio_recording_statistics)).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  its('class.primary_key') { is_expected.to eq(['audio_recording_id', 'bucket']) }

  it { is_expected.to validate_numericality_of(:original_download_count).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:segment_download_count).is_greater_than_or_equal_to(0).only_integer }
  it { is_expected.to validate_numericality_of(:segment_download_duration).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:analyses_completed_count).is_greater_than_or_equal_to(0).only_integer }

  context 'with fixtures' do
    create_audio_recordings_hierarchy

    it_behaves_like 'a model with a temporal stats bucket', {
      model: Statistics::AudioRecordingStatistics,
      parent_factory: :audio_recording,
      parent: :audio_recording,
      other_key: :audio_recording_id
    }

    it_behaves_like 'a stats segment incrementor', {
      model: Statistics::AudioRecordingStatistics,
      increment: ->(duration) { Statistics::AudioRecordingStatistics.increment_segment(audio_recording, duration:) },
      duration_key: :segment_download_duration,
      count_key: :segment_download_count
    }

    context 'when inserting stats' do
      it 'can increment original download count' do
        Statistics::AudioRecordingStatistics.increment_original(audio_recording)

        stats = Statistics::AudioRecordingStatistics.first
        expect(stats.original_download_count).to eq 1

        Statistics::AudioRecordingStatistics.increment_original(audio_recording)

        stats.reload
        expect(stats.original_download_count).to eq 2

        audio_recording.reload_statistics
        actual = audio_recording.statistics
        expect(actual.original_download_count).to eq 2
      end

      it 'can increment segment download count' do
        Statistics::AudioRecordingStatistics.increment_segment(audio_recording, duration: 30)

        stats = Statistics::AudioRecordingStatistics.first
        expect(stats.segment_download_count).to eq 1
        expect(stats.segment_download_duration).to eq 30.0

        Statistics::AudioRecordingStatistics.increment_segment(audio_recording, duration: 12.5)

        stats.reload
        expect(stats.segment_download_count).to eq 2
        expect(stats.segment_download_duration).to eq 42.5

        audio_recording.reload_statistics
        actual = audio_recording.statistics
        expect(actual.segment_download_count).to eq 2
        expect(actual.segment_download_duration).to eq 42.5
      end

      it 'can increment analysis count' do
        Statistics::AudioRecordingStatistics.increment_analysis_count(audio_recording)

        stats = Statistics::AudioRecordingStatistics.first
        expect(stats.analyses_completed_count).to eq 1

        Statistics::AudioRecordingStatistics.increment_analysis_count(audio_recording)

        stats.reload
        expect(stats.analyses_completed_count).to eq 2

        audio_recording.reload_statistics
        actual = audio_recording.statistics
        expect(actual.analyses_completed_count).to eq 2
      end
    end
  end

  it_behaves_like 'cascade deletes for', :audio_recording_statistic, {} do
    create_entire_hierarchy
  end
end
