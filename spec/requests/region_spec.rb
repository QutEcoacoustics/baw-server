

describe 'Regions' do
  create_audio_recordings_hierarchy

  it_behaves_like :a_route_that_stores_images, {
    route: '/regions',
    current: :region,
    field_name: :image,
    model_name: :region
  }
end
