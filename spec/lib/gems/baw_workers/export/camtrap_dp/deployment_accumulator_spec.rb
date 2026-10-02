# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::DeploymentAccumulator do
  create_audio_recordings_hierarchy

  subject(:accumulator) { BawWorkers::Export::CamtrapDp::DeploymentAccumulator.new }

  let(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }
  let(:tagging) { create(:tagging, audio_event:, creator: writer_user) }

  describe '#add_or_update' do
    it 'uses bounds from all site recordings, including recordings without exported taggings' do
      earliest = create(:audio_recording, site:, creator: writer_user,
        recorded_date: audio_recording.recorded_date - 1.day)
      latest = create(:audio_recording, site:, creator: writer_user,
        recorded_date: audio_recording.recorded_date + 1.day)

      deployment = accumulator.add_or_update(tagging)

      expect(deployment.start).to eq(earliest.recorded_date)
      expect(deployment.end).to eq(latest.recorded_end_date)
    end

    it 'keeps one deployment per site when taggings are loaded separately' do
      accumulator.add_or_update(tagging)
      accumulator.add_or_update(Tagging.find(tagging.id))

      expect(accumulator.values.map(&:site)).to eq([site])
    end

    it 'marks media private when the site does not allow anonymous access' do
      expect(accumulator.add_or_update(tagging).file_public).to be(false)
    end

    it 'marks media public when the site allows anonymous access' do
      create(:read_anon_permission, creator: owner_user, project:)

      expect(accumulator.add_or_update(tagging).file_public).to be(true)
    end
  end

  describe '#initialize' do
    it 'rejects an invalid forced timezone' do
      expect { BawWorkers::Export::CamtrapDp::DeploymentAccumulator.new(forced_timezone: 'invalid') }.to raise_error(
        ArgumentError, /forced_timezone: got String, expected ActiveSupport::TimeZone or TZInfo::Timezone/
      )
    end
  end
end
