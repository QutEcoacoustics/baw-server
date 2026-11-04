# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/bookmarks_spec.rb.

describe 'Bookmark filtering (ported)', type: :request do
  create_audio_recordings_hierarchy

  [:reader, :writer].each do |role|
    context "as the #{role}" do
      let(:creator) { public_send(:"#{role}_user") }
      let(:token) { public_send(:"#{role}_token") }

      [:name, :category].each do |field|
        it "filters by #{field}, excluding nonmatching and other users' bookmarks" do
          matching = create(:bookmark, creator:, audio_recording:, field => 'the_expected_value')
          create(:bookmark, creator:, audio_recording:, field => 'the_unexpected_value')
          create(:bookmark, creator: no_access_user, audio_recording:, field => 'the_expected_value')

          get '/bookmarks', params: { "filter_#{field}": 'the_expected_value' }, **api_headers(token)

          expect_success
          expect(api_data).to match([
            a_hash_including(id: matching.id, field => 'the_expected_value', offset_seconds: 4.0)
          ])
        end
      end
    end
  end

  it 'returns a new template with the editable bookmark fields' do
    get '/bookmarks/new', **api_headers(reader_token)

    expect_success
    expect(api_data).to eq(name: nil, category: nil, description: nil, offset_seconds: nil)
  end

  it 'shows the stored offset to the creator' do
    bookmark = create(:bookmark, creator: writer_user, audio_recording:, offset_seconds: 4)

    get "/bookmarks/#{bookmark.id}", **api_headers(writer_token)

    expect_success
    expect(api_data).to include(id: bookmark.id, offset_seconds: 4.0)
  end

  it 'combines offset and description filters and projects the category' do
    matching = create(:bookmark, creator: writer_user, audio_recording:,
      offset_seconds: 4, description: 'matching description', category: 'expected category')
    create(:bookmark, creator: writer_user, audio_recording:,
      offset_seconds: 123_456, description: 'matching description')
    create(:bookmark, creator: writer_user, audio_recording:,
      offset_seconds: 4, description: 'unrelated text')
    create(:bookmark, creator: reader_user, audio_recording:,
      offset_seconds: 4, description: 'matching description')

    post '/bookmarks/filter', params: {
      filter: {
        and: {
          offset_seconds: { less_than: 123_456 },
          description: { contains: 'description' }
        }
      },
      projection: { include: ['category'] }
    }, **api_with_body_headers(writer_token)

    expect_success
    expect(api_data).to eq([{ category: matching.category }])
    expect_has_projection(only: ['category'])
  end
end
