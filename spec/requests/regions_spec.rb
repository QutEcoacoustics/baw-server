# frozen_string_literal: true

describe '/regions' do
  create_audio_recordings_hierarchy

  it_behaves_like 'a route that stores images', {
    route: '/regions',
    current: :region,
    field_name: :image,
    model_name: :region,
    factory_args: -> { { project_id: project.id } }
  }

  context 'with bad params' do
    render_error_responses

    it 'will not accept notes via form data' do
      old_notes = region.notes

      put "/regions/#{region.id}", params: {
        'region[notes]' => { a: 3 }
      }, **form_multipart_headers(owner_token)

      expect_error(
        :unprocessable_entity,
        'The request could not be understood: found unpermitted parameter: :notes'
      )

      region.reload

      expect(region.notes).to eq old_notes
    end
  end
end
