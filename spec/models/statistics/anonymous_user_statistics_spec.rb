# frozen_string_literal: true

# == Schema Information
#
# Table name: anonymous_user_statistics
#
#  audio_download_duration       :decimal(, )      default(0.0)
#  audio_original_download_count :bigint           default(0)
#  audio_segment_download_count  :bigint           default(0)
#  bucket                        :tsrange          not null, primary key
#
# Indexes
#
#  constraint_baw_anonymous_user_statistics_unique  (bucket) UNIQUE
#

RSpec.describe Statistics::AnonymousUserStatistics, type: :model do
  subject { build(:anonymous_user_statistics) }

  it 'has a valid factory' do
    expect(create(:anonymous_user_statistics)).to be_valid
  end

  it { is_expected.not_to belong_to(:user) }

  its('class.primary_key') { is_expected.to eq('bucket') }

  it {
    is_expected.to validate_numericality_of(:audio_original_download_count)
      .is_greater_than_or_equal_to(0)
      .only_integer
  }

  it {
    is_expected.to validate_numericality_of(:audio_segment_download_count).is_greater_than_or_equal_to(0).only_integer
  }

  it { is_expected.to validate_numericality_of(:audio_download_duration).is_greater_than_or_equal_to(0) }

  context 'with data' do
    create_audio_recordings_hierarchy

    it_behaves_like 'a model with a temporal stats bucket', {
      model: Statistics::AnonymousUserStatistics,
      parent_factory: nil,
      parent: nil,
      other_key: nil
    }

    it_behaves_like 'a stats segment incrementor', {
      model: Statistics::AnonymousUserStatistics,
      increment: ->(duration) { Statistics::AnonymousUserStatistics.increment_segment(duration:) },
      duration_key: :audio_download_duration,
      count_key: :audio_segment_download_count
    }

    context 'when inserting stats' do
      it 'can increment original download count' do
        Statistics::AnonymousUserStatistics.increment_original(audio_recording)

        stats = Statistics::AnonymousUserStatistics.first
        expect(stats.audio_original_download_count).to eq 1
        expect(stats.audio_download_duration).to eq audio_recording.duration_seconds

        Statistics::AnonymousUserStatistics.increment_original(audio_recording)
        stats.reload
        expect(stats.audio_original_download_count).to eq 2
        expect(stats.audio_download_duration).to eq(audio_recording.duration_seconds * 2)

        actual = Statistics::AnonymousUserStatistics.first
        expect(actual.audio_original_download_count).to eq 2
        expect(actual.audio_download_duration).to eq(audio_recording.duration_seconds * 2)
      end

      it 'can increment segment download count' do
        Statistics::AnonymousUserStatistics.increment_segment(duration: 30)

        stats = Statistics::AnonymousUserStatistics.first
        expect(stats.audio_segment_download_count).to eq 1
        expect(stats.audio_download_duration).to eq 30.0

        Statistics::AnonymousUserStatistics.increment_segment(duration: 12.5)

        stats.reload
        expect(stats.audio_segment_download_count).to eq 2
        expect(stats.audio_download_duration).to eq 42.5

        actual = Statistics::AnonymousUserStatistics.first
        expect(actual.audio_segment_download_count).to eq 2
        expect(actual.audio_download_duration).to eq 42.5
      end
    end
  end
end
