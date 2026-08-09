# frozen_string_literal: true

describe Api::GlobalIdentifiers do
  create_entire_hierarchy

  let(:authority) { Settings.global_identifiers.authority }

  describe 'AudioRecording#global_identifier' do
    it 'produces a global identifier with the configured authority and the audio recording path' do
      expect(audio_recording.global_identifier).to eq(
        "#{authority}/audio_recordings/#{audio_recording.id}"
      )
    end
  end

  describe 'Script#global_identifier' do
    it 'produces a global identifier with the configured authority and the script path' do
      expect(script.global_identifier).to eq(
        "#{authority}/scripts/#{script.id}"
      )
    end
  end

  describe 'AnalysisJob#global_identifier' do
    it 'produces a global identifier with the configured authority and the analysis job path' do
      expect(analysis_job.global_identifier).to eq(
        "#{authority}/analysis_jobs/#{analysis_job.id}"
      )
    end
  end

  describe 'Provenance#global_identifier' do
    it 'produces a global identifier with the configured authority and the provenance path' do
      provenance = script.provenance
      expect(provenance.global_identifier).to eq(
        "#{authority}/provenances/#{provenance.id}"
      )
    end
  end

  describe 'Site#global_identifier' do
    it 'produces a global identifier with the configured authority and the site path' do
      expect(site.global_identifier).to eq(
        "#{authority}/sites/#{site.id}"
      )
    end
  end

  describe 'Api::UrlHelpers.global_identifier' do
    it 'combines authority from settings with the generated path' do
      result = Api::UrlHelpers.global_identifier(:audio_recording_path, id: audio_recording.id)
      expect(result).to eq("#{authority}/audio_recordings/#{audio_recording.id}")
    end

    it 'uses the authority configured in Settings.global_identifiers.authority' do
      # Verify the authority setting is non-empty and formatted as a bare hostname (no scheme)
      expect(authority).to be_present
      expect(authority).not_to start_with('http')
    end
  end
end
