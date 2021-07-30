# frozen_string_literal: true

describe '/regions' do
  create_audio_recordings_hierarchy

  it_behaves_like 'a route that stores images', {
    route: '/regions',
    current: :region,
    field_name: :image,
    model_name: :region
  }
end
