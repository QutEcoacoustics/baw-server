# frozen_string_literal: true

describe 'Reports permissions' do
  create_entire_hierarchy

  given_the_route '/reports' do
    {
      id: :invalid
    }
  end

  send_create_body do
    [{}, :json]
  end

  send_update_body do
    [{}, :json]
  end

  let(:day) { audio_recording.recorded_date.utc.at_beginning_of_day }

  with_custom_action(:tag_accumulation, path: 'tag_accumulation', verb: :post,
    body: -> { { options: { bucket_size: 'day' }, filter: {} } },
    expect: lambda { |user, _action|
      if user == :no_access
        expect(api_result[:data].length).to eq(0)
      else
        expect(api_data).to match([{ bucket: [day, day + 1.day], cumulative_unique_tag_count: 1.0 }])
      end
    })

  # Any authenticated user with at least reader access can use the tag_accumulation endpoint
  ensures :admin, :owner, :writer, :reader,
    can: [:tag_accumulation],
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Users without project access cannot see any results (empty response but still succeeds)
  ensures :no_access,
    can: [:tag_accumulation],
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Harvester cannot access the endpoint
  ensures :harvester,
    cannot: [:tag_accumulation],
    fails_with: :forbidden

  ensures :harvester,
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Anonymous users cannot access the endpoint
  ensures :anonymous,
    cannot: [:tag_accumulation],
    fails_with: :unauthorized

  ensures :anonymous,
    cannot: [:index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: :not_found

  # Invalid tokens cannot access the endpoint
  ensures :invalid,
    cannot: [:tag_accumulation, :index, :show, :create, :update, :destroy, :new, :filter],
    fails_with: [:unauthorized, :not_found]
end
