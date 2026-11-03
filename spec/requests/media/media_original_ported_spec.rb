# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/media/media_original_spec.rb.

# Denials from media_original_spec.rb:76-120 are covered by
# spec/permissions/media/media_original_spec.rb; these preserve the full-file callbacks.
describe 'Original media full-file downloads', :aggregate_failures, type: :request do
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  let!(:test_file) {
    audio_recording.update!(
      duration_seconds: 3600,
      media_type: 'audio/ogg',
      original_file_name: 'original.ogg',
      data_length_bytes: audio_file_mono_data_length_bytes
    )
    link_original_audio(
      target: Fixtures.audio_file_mono,
      uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date,
      original_format: 'ogg'
    )
  }

  after do
    test_file.unlink
  end

  [:admin, :harvester].each do |user|
    it "serves the complete long recording and exact download headers as #{user}" do
      get "/audio_recordings/#{audio_recording.id}/original",
        headers: media_request_headers(send(:"#{user}_token"), format: 'ogg')

      expect_success
      filename = audio_recording.friendly_name
      expect(response.media_type).to eq(audio_recording.media_type)
      expect(response.body.b).to eq(Fixtures.audio_file_mono.binread)
      expect(response.headers).to include(
        'Content-Length' => audio_file_mono_data_length_bytes.to_s,
        'Content-Disposition' => "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}",
        'Digest' => "SHA256=#{audio_recording.split_file_hash[1]}",
        'Content-Transfer-Encoding' => 'binary',
        'Accept-Ranges' => 'bytes'
      )
      expect(response.headers['Content-Range']).to be_nil
    end
  end
end
