# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Table::Media do
  create_audio_recordings_hierarchy

  subject(:media) do
    row = table.mapping(audio_recording, deployment).ordered_values
    table.attribute_names.zip(row).to_h
  end

  let(:table) { BawWorkers::Export::CamtrapDp::Table::Media }

  let(:deployment) do
    BawWorkers::Export::CamtrapDp::DeploymentAccumulator::Deployment.new(
      site:,
      start: audio_recording.recorded_date,
      end: audio_recording.recorded_end_date,
      file_public: false,
      timezone: ActiveSupport::TimeZone['UTC']
    )
  end

  describe '.mapping' do
    it 'maps the original recording URL and audio properties' do
      expect(media).to include(
        mediaID: audio_recording.global_identifier,
        deploymentID: site.global_identifier,
        duration: audio_recording.duration_seconds,
        filePath: Api::UrlHelpers.audio_recording_media_original_url(audio_recording_id: audio_recording.id),
        filePublic: false,
        fileName: audio_recording.friendly_name,
        fileMediatype: audio_recording.media_type,
        samplingFrequency: audio_recording.sample_rate_hertz,
        channels: audio_recording.channels
      )
    end

    context 'with a public deployment' do
      let(:deployment) { super().with(file_public: true) }

      it 'marks the media file as public' do
        expect(media.fetch(:filePublic)).to be(true)
      end
    end
  end
end
