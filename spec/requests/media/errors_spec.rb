# frozen_string_literal: true

describe '.../media', type: :request, aggregate_failures: true do
  include_context 'shared_test_helpers'

  create_audio_recordings_hierarchy

  let!(:lt_recording) {
    FactoryBot.create(
      :audio_recording,
      recorded_date: Time.zone.parse('2019-09-13T00:00:01+1000 '),
      duration_seconds: audio_file_bar_lt_metadata[:duration_seconds],
      media_type: audio_file_bar_lt_metadata[:format],
      original_file_name: Fixtures.bar_lt_file.basename,
      status: :ready,
      site: site
    )
  }

  context 'when given bad parameters it should not send error emails' do
    # when exceptions are unhandled an email is sent

    # for tests, we want error responses to rendered, the default is to raise an
    # exception
    render_error_responses
    pause_all_jobs

    cases =
      [:head, :get].product([
        [
          'start_offset=-3&end_offset=30',
          'Custom Errors/Unprocessable Entity Error',
          'start_offset parameter (-3.0) must be greater than or equal to 0.'
        ],
        [
          'start_offset=7180&end_offset=7210',
          'Custom Errors/Unprocessable Entity Error',
          'end_offset parameter (7210.0) must be smaller than or equal to the duration of the audio recording (7194.7494).'
        ],
        [
          'start_offset=0&end_offset=6000',
          'Custom Errors/Requested Media Duration Invalid',
          'Requested duration 6000.0 (0.0 to 6000.0) is greater than maximum (300.0).'
        ]
      ])

    cases.each do |(method, (qsp, expected_error_type, expected_error_message))|
      context "for #{method} media.mp3?#{qsp}" do
        let(:url) { "/audio_recordings/#{lt_recording.id}/media.mp3?" + qsp }

        before do
          clear_mail
          process method, url, headers: media_request_headers(reader_token)
        end

        it 'does not send an exception email' do
          expect_no_sent_mail
        end

        it 'indicates an error message in the X-Error header' do
          expect_headers_to_include({
            'X-Error-Type' => expected_error_type,
            'X-Error-Message' => expected_error_message
          })
        end

        it 'has a error response code' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'has no body' do
          expect_empty_body
        end
      end
    end
  end
end
