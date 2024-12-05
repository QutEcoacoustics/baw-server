# frozen_string_literal: true

require_relative 'audio_event_import_context'

describe 'permissions' do
  include_context 'with audio event import context'

  let(:another_project) {
    create(:project)
  }

  let(:another_region) {
    create(:region, project: another_project)
  }

  let(:another_site) {
    create(:site, region: another_region)
  }

  let(:another_audio_recording) {
    create(:audio_recording, site: another_site)
  }

  disable_cookie_jar

  before do
    AudioEvent.delete_all
    create_import
  end

  [true, false].each do |commit|
    describe "(with commit: #{commit})" do
      it 'does not allow audio event creation for projects a user does not have write access too' do
        f = temp_file(extension: 'csv')
        f.write <<~CSV
          audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
          #{audio_recording.id}       ,123               ,456             ,100                ,500                 ,Birb
          #{another_audio_recording.id},123              ,456             ,100                ,500                 ,Birb
        CSV

        submit(f, commit:)

        expect_error(
          :unprocessable_content,
          'Record could not be saved',
          {
            file: ['Validation failed']
          },
          with_data_matching: a_hash_including(
           imported_events: [
             a_hash_including(
               audio_recording_id: audio_recording.id,
               errors: an_instance_of(Array).and(have_attributes(size: 0))
             ),
             a_hash_including(
               audio_recording_id: another_audio_recording.id,
               errors: [
                 {
                   audio_recording_id: ['you do not have permission to add audio events to this recording']
                 }
               ]
             )
           ]
         )
        )

        expect(AudioEvent.count).to eq 0
      end

      it 'does not allow readers to upload events' do
        submit(generic_example, commit:, user: reader_token)

        expect_error(:forbidden, nil)

        expect(AudioEvent.count).to eq 0
      end
    end
  end
end
