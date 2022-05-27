# frozen_string_literal: true

require 'swagger_helper'

describe 'harvest items (normal listing)', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  before do
    create(:harvest_item, harvest:)
  end

  sends_json_and_expects_json
  with_authorization
  for_model HarvestItem
  which_has_schema ref(:harvest_item)

  let(:harvest_id) { harvest.id }

  with_route_parameter(:harvest_id)

  path '/harvests/{harvest_id}/items/filter' do
    post('filter harvest items') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect(HarvestItem.count).to eq 1
          expect_at_least_one_item
        end
      end
    end
  end
end

describe 'harvest items (nested, normal listing)', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  before do
    create(:harvest_item, harvest:)
  end

  sends_json_and_expects_json
  with_authorization
  for_model HarvestItem
  which_has_schema ref(:harvest_item)

  let(:harvest_id) { harvest.id }
  let(:project_id) { project.id }

  with_route_parameter(:harvest_id)
  with_route_parameter(:project_id)

  path '/projects/{project_id}/harvests/{harvest_id}/items/filter' do
    post('filter harvest items') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end
end

# ---

describe 'harvest items (path listing)', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  before do
    create(:harvest_item, harvest:, path: "#{harvest.upload_directory_name}/a/b/c.wav")
  end

  sends_json_and_expects_json
  with_authorization
  for_model HarvestItem
  which_has_schema ref(:harvest_item)

  let(:harvest_id) { harvest.id }

  with_route_parameter(:harvest_id)

  path '/harvests/{harvest_id}/items/a/b' do
    get('list harvest items by path') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect(HarvestItem.count).to eq 1
          expect_at_least_one_item
        end
      end
    end
  end
end

describe 'harvest items (nested, path listing)', type: :request do
  create_audio_recordings_hierarchy
  prepare_anonymous_access(:project)
  prepare_logged_in_access(:project)
  prepare_harvest

  before do
    create(:harvest_item, harvest:, path: "#{harvest.upload_directory_name}/a/b/c.wav")
  end

  sends_json_and_expects_json
  with_authorization
  for_model HarvestItem
  which_has_schema ref(:harvest_item)

  let(:harvest_id) { harvest.id }
  let(:project_id) { project.id }

  with_route_parameter(:harvest_id)
  with_route_parameter(:project_id)

  path '/projects/{project_id}/harvests/{harvest_id}/items/a/b' do
    get('list harvest items by path') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end
end
