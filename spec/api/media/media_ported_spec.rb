# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/media/media_spec.rb.

require 'swagger_helper'

# media_spec.rb:62-345,596-698: default/modified metadata and native-rate filtering.
describe 'Media metadata', :aggregate_failures, type: :request do
  create_audio_recordings_hierarchy

  with_authorization
  for_model AudioRecording

  object = lambda { |properties|
    { type: :object, required: properties.keys, additionalProperties: false, properties: }
  }
  integer = { type: :integer }
  number = { type: :number }
  string = { type: :string }
  integer_parameter = { oneOf: [integer, { type: :string, pattern: '^[0-9]+$' }] }
  link = object.call(media_type: string, extension: string, url: string)
  image = object.call(
    window_size: integer, window_function: string, colour: string, ppms: number,
    media_type: string, extension: string, url: string
  )
  recording = object.call(
    id: integer, uuid: { type: :string, format: :uuid },
    recorded_date: { type: :string, format: 'date-time' },
    duration_seconds: number, sample_rate_hertz: integer, channel_count: integer, media_type: string
  )
  common = object.call(
    start_offset: number, end_offset: number,
    audio_event_id: { nullable: true, type: :integer },
    channel: integer_parameter, sample_rate: integer_parameter
  )
  rates = { type: :array, items: integer }
  options = object.call(
    channels: rates,
    audio: object.call(
      duration_max: number, duration_min: number,
      formats: {
        type: :array, minItems: 5, maxItems: 5,
        items: object.call(name: string, valid_sample_rates: rates)
      }
    ),
    image: object.call(
      spectrogram: object.call(
        duration_max: number, duration_min: number,
        formats: { type: :array, items: string },
        window_sizes: rates, window_functions: { type: :array, items: string },
        colours: object.call([:g, :h, :pr, :tg, :yg, :gr, :tb, :rb, :w].index_with { string }),
        valid_sample_rates: rates
      )
    ),
    text: object.call(formats: { type: :array, items: string })
  )
  media_metadata = {
    type: :object,
    required: %i[recording common_parameters available],
    additionalProperties: false,
    properties: {
      recording:,
      common_parameters: common,
      available: object.call(
        audio: {
          type: :object,
          required: %i[webm ogg flac wav],
          additionalProperties: false,
          properties: { mp3: link, webm: link, ogg: link, flac: link, wav: link }
        },
        image: object.call(png: image),
        text: object.call(json: link)
      ),
      options:
    }
  }
  which_has_schema media_metadata

  [
    ['default', 44_100, {}, ['mp3', 'webm', 'ogg', 'flac', 'wav']],
    ['96000 Hz', 44_100, { sample_rate: 96_000 }, ['webm', 'ogg', 'flac', 'wav']],
    ['modified offsets and sample rate', 44_100, { start_offset: 1, end_offset: 2, sample_rate: 11_025 },
     ['mp3', 'webm', 'ogg', 'flac', 'wav']],
    ['native non-standard rate', 7777, { sample_rate: 7777 }, ['webm', 'ogg', 'flac', 'wav']],
    ['default non-standard rate', 7777, {}, ['webm', 'ogg', 'flac', 'wav']]
  ].each do |description, native_rate, query, audio_formats|
    context description do
      before do
        audio_recording.update!(sample_rate_hertz: native_rate)
      end

      path '/audio_recordings/{audio_recording_id}/media.json' do
        get "Media metadata: #{description}" do
          tags 'media'
          consumes nil
          produces 'application/json'
          parameter name: :audio_recording_id, in: :path, type: :integer, required: true
          let(:audio_recording_id) { audio_recording.id }

          query.each do |name, value|
            parameter name:, in: :query, type: :integer, required: true
            let(name) { value }
          end

          response '200', 'media metadata' do
            schema_for_single

            run_test! do
              data = api_data
              expect(data[:recording]).to include(
                id: audio_recording.id,
                uuid: audio_recording.uuid,
                sample_rate_hertz: native_rate,
                channel_count: audio_recording.channels
              )
              expect(data[:common_parameters]).to include(
                start_offset: query.fetch(:start_offset, 0).to_f,
                end_offset: query.fetch(:end_offset, audio_recording.duration_seconds).to_f
              )
              expect(data[:common_parameters][:sample_rate].to_i).to eq(query.fetch(:sample_rate, native_rate))
              expect(data[:available][:audio].keys.map(&:to_s)).to eq(audio_formats)

              if audio_formats.include?('mp3')
                expect(data[:available][:audio][:mp3][:media_type]).to eq('audio/mpeg')
                expect(response.body).not_to include('audio/mp3')
              end

              if query.empty?
                formats = data[:options][:audio][:formats].index_by { |format| format[:name] }
                standard_rates = [8000, 11_025, 12_000, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000]
                expect(formats.fetch('mp3')[:valid_sample_rates]).to eq(standard_rates)
                wav_rates = standard_rates + [96_000]
                wav_rates << 7777 if native_rate == 7777
                expect(formats.fetch('wav')[:valid_sample_rates]).to eq(wav_rates)
              else
                expect(data).not_to have_key(:options)
              end
            end
          end
        end
      end
    end
  end
end
