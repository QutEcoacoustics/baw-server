# frozen_string_literal: true

require_relative 'audio_event_parser_context'

describe Api::AudioEventParser do
  include_context 'audio_event_parser'

  describe 'importing a website export' do
    let(:baw_format) {
      <<~CSV
        audio_event_id,audio_recording_id,audio_recording_uuid,audio_recording_start_date_australia_brisbane_10_00,audio_recording_start_time_australia_brisbane_10_00,audio_recording_start_datetime_australia_brisbane_10_00,event_created_at_date_australia_brisbane_10_00,event_created_at_time_australia_brisbane_10_00,event_created_at_datetime_australia_brisbane_10_00,projects,site_id,site_name,event_start_date_australia_brisbane_10_00,event_start_time_australia_brisbane_10_00,event_start_datetime_australia_brisbane_10_00,event_start_seconds,event_end_seconds,event_duration_seconds,low_frequency_hertz,high_frequency_hertz,is_reference,created_by,updated_by,common_name_tags,common_name_tag_ids,species_name_tags,species_name_tag_ids,other_tags,other_tag_ids,listen_url,library_url
        259695,#{audio_recording.id},d9e5c6c1-aabf-482c-8f52-83f05531970c,2015-06-01,12:24:16,2015-06-01T12:24:16+10:00,2018-07-01,03:00:23,2018-07-01T03:00:23+10:00,1033:Bristle Whistle,1186,CWS Aviaries (0m) ,2015-06-01,12:41:37,2015-06-01T12:41:37+10:00,1041.6642,1042.9645,1.3003,3143.8477,8397.9492,false,639,639,,,,,,,http://api.ecosounds.org/listen/262864?start=1020&end=1050,http://api.ecosounds.org/library/262864/audio_events/259695
        259314,#{another_recording.id},d9e5c6c1-aabf-482c-8f52-83f05531970c,2015-06-01,12:24:16,2015-06-01T12:24:16+10:00,2018-06-10,10:51:57,2018-06-10T10:51:57+10:00,1033:Bristle Whistle,1186,CWS Aviaries (0m) ,2015-06-01,12:41:11,2015-06-01T12:41:11+10:00,1015.6348,1018.1658,2.531,1636.5234,7795.0195,true,639,639,63:Crickets|74:Eastern Bristlebird|147:Pied Currawong,63|74|147,,,595:unsure:general|1142:overlap:general,595|1142,http://api.ecosounds.org/listen/262864?start=990&end=1020,http://api.ecosounds.org/library/262864/audio_events/259314

      CSV
    }

    let(:baw_basename) {
      'bristle_whistle_1033_cws_aviaries_0m_1186-20220829-025114.csv'
    }

    it 'can parse events' do
      parser = Api::AudioEventParser.new(import_file, writer_user)
      parser.parse_and_commit(baw_format, baw_basename)

      results = parser.serialize_audio_events
      expect(results.size).to be(2)
      expect(results).to all(be_an_instance_of(Hash))

      results => [r1, r2]

      expect(r1).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: audio_recording.id,
        start_time_seconds: 1041.6642,
        end_time_seconds: 1042.9645,
        low_frequency_hertz: 3143.8477,
        high_frequency_hertz: 8397.9492,
        is_reference: false,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty),
        import_file_index: 0
      ))

      expect(r1[:tags]).to match([])

      expect(r2).to match(a_hash_including(
        audio_event_import_file_id: import.audio_event_import_files.first.id,
        audio_recording_id: another_recording.id,
        start_time_seconds: 1015.6348,
        end_time_seconds: 1018.1658,
        low_frequency_hertz: 1636.5234,
        high_frequency_hertz: 7795.0195,
        is_reference: true,
        id: an_instance_of(Integer),
        errors: an_instance_of(Array).and(be_empty),
        import_file_index: 1
      ))

      expect(r2[:tags]).to match([
        a_hash_including(
          text: tag_crickets.text,
          id: tag_crickets.id
        ),
        a_hash_including(
          text: 'Eastern Bristlebird'
        ),
        a_hash_including(
          text: 'Pied Currawong'
        ),
        a_hash_including(
          text: 'unsure'
        ),
        a_hash_including(
          text: 'overlap'
        )
      ])
    end
  end
end
