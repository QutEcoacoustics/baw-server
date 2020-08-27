require 'swagger_helper'

describe 'bookmarks', type: :request do
  create_entire_hierarchy

  # bookmarks are ties to user that made them
  let(:bookmark) {
    FactoryBot.create(:bookmark, creator: admin_user, audio_recording: audio_recording)
  }

  sends_json_and_expects_json
  with_authorization
  for_model Bookmark
  which_has_schema ref(:bookmark)

  path '/bookmarks/filter' do
    post('filter bookmark') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/bookmarks' do
    get('list bookmarks') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create bookmark') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/bookmarks/new' do
    get('new bookmark') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/bookmarks/{id}' do
    with_id_route_parameter
    let(:id) { bookmark.id }

    get('show bookmark') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(bookmark)
        end
      end
    end

    patch('update bookmark') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(bookmark)
        end
      end
    end

    put('update bookmark') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(bookmark)
        end
      end
    end

    delete('delete bookmark') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
