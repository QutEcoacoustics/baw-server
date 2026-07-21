# frozen_string_literal: true

describe BawWorkers::Export::CamtrapDp::Identifier do
  def expected_client_authority
    port = Settings.client.port.present? ? ":#{Settings.client.port}" : ''

    "#{Settings.client.host}#{port}"
  end

  describe '.with_host' do
    it 'uses the configured client host and port' do
      expect(described_class.with_host('/sites/123')).to eq("#{expected_client_authority}/sites/123")
    end

    it 'omits the port when the configured client port is blank' do
      allow(Settings.client).to receive(:port).and_return(nil)

      expect(described_class.with_host('/sites/123')).to eq("#{Settings.client.host}/sites/123")
    end
  end

  describe '.tagging' do
    it 'uses the configured client host and nested tagging path' do
      tagging = create(:tagging)
      audio_event = tagging.audio_event
      audio_recording = audio_event.audio_recording

      expect(described_class.tagging(tagging)).to eq(
        "#{expected_client_authority}/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}/taggings/#{tagging.id}"
      )
    end
  end

  describe '.audio_recording' do
    it 'uses the configured client host and audio recording path' do
      audio_recording = create(:audio_recording)

      expect(described_class.audio_recording(audio_recording)).to eq(
        "#{expected_client_authority}/audio_recordings/#{audio_recording.id}"
      )
    end
  end

  describe '.site' do
    it 'uses the configured client host and site path' do
      site = create(:site)

      expect(described_class.site(site)).to eq("#{expected_client_authority}/sites/#{site.id}")
    end
  end
end
