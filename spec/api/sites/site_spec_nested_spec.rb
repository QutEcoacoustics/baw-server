# frozen_string_literal: true

require 'swagger_helper'

describe 'sites (nested)' do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Site, factory_args: -> { { projects: [project] } }
  which_has_schema ref(:site)

  let(:project_id) { project.id }

  with_route_parameter(:project_id)

  path '/projects/{project_id}/sites/filter' do
    post('filter site') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/projects/{project_id}/sites' do
    get('list sites') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create site') do
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        auto_send_model
        run_test!
      end
    end
  end

  path '/projects/{project_id}/sites/new' do
    get('new site') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/projects/{project_id}/sites/{id}' do
    with_route_parameter(:project_id)
    with_id_route_parameter
    let(:id) { site.id }

    get('show site') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    patch('update site') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    put('update site') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        auto_send_model
        run_test! do
          expect_id_matches(site)
        end
      end
    end

    delete('delete site') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end

describe 'sites (orphans)' do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Site
  which_has_schema ref(:site)

  let!(:orphaned_site) {
    s = build(:site, projects: [], project_ids: [])
    # intentionally invalid
    s.save!(validate: false)
    s
  }

  path '/sites/orphans/filter' do
    post('filter site') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(orphaned_site.id)
        end
      end
    end
  end

  path '/sites/orphans' do
    get('list sites') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_has_ids(orphaned_site.id)
        end
      end
    end
  end
end
