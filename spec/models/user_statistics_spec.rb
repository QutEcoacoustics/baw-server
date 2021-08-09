# frozen_string_literal: true

# == Schema Information
#
# Table name: user_statistics
#
#  audio_download_duration       :decimal(, )      default(0.0)
#  audio_original_download_count :bigint           default(0)
#  audio_segment_download_count  :bigint           default(0)
#  bucket                        :tsrange          not null, primary key
#  user_id                       :bigint           primary key
#
# Indexes
#
#  constraint_baw_user_statistics_non_overlapping  (user_id,bucket) USING gist
#  constraint_baw_user_statistics_unique           (user_id,bucket) UNIQUE
#  index_user_statistics_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

RSpec.describe UserStatistics, type: :model do
  subject { FactoryBot.build(:user_statistics) }

  it 'has a valid factory' do
    expect(FactoryBot.create(:user_statistics)).to be_valid
  end

  it { is_expected.to belong_to(:user).optional(true) }

  its('class.primary_key') { is_expected.to eq(['user_id', 'bucket']) }

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
      model: UserStatistics,
      parent_factory: :user,
      parent: :reader_user,
      other_key: :user_id
    }

    context 'when inserting stats' do
      it 'can increment original download count' do
        UserStatistics.increment_original(reader_user, audio_recording)

        stats = UserStatistics.first
        expect(stats.audio_original_download_count).to eq 1
        expect(stats.audio_download_duration).to eq audio_recording.duration_seconds

        UserStatistics.increment_original(reader_user, audio_recording)
        stats.reload
        expect(stats.audio_original_download_count).to eq 2
        expect(stats.audio_download_duration).to eq(audio_recording.duration_seconds * 2)

        reader_user.reload_statistics
        actual = reader_user.statistics
        expect(actual.audio_original_download_count).to eq 2
        expect(actual.audio_download_duration).to eq(audio_recording.duration_seconds * 2)
      end

      it 'can increment segment download count' do
        UserStatistics.increment_segment(reader_user, duration: 30)

        stats = UserStatistics.first
        expect(stats.audio_segment_download_count).to eq 1
        expect(stats.audio_download_duration).to eq 30.0

        UserStatistics.increment_segment(reader_user, duration: 12.5)

        stats.reload
        expect(stats.audio_segment_download_count).to eq 2
        expect(stats.audio_download_duration).to eq 42.5

        reader_user.reload_statistics
        actual = reader_user.statistics
        expect(actual.audio_segment_download_count).to eq 2
        expect(actual.audio_download_duration).to eq 42.5
      end
    end
  end
end
