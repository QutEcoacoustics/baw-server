# frozen_string_literal: true

RSpec.shared_examples 'a documented archivable route' do |base_route, instance, describe_hook|
  let(:resolved_instance) { instance_exec(&instance) }
  before do
    instance_exec(&instance).discard!
  end

  path base_route.to_s do
    let(:archived_qsp) { true }

    describe_hook&.call
    parameter(**Api::Schema.archived_parameter)

    get('list archived') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path "#{base_route}/filter" do
    let(:archived_qsp) { true }

    describe_hook&.call
    parameter(**Api::Schema.archived_parameter)
    post('filter archived') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path "#{base_route}/{id}" do
    let(:archived_qsp) { true }
    let(:id) { resolved_instance.id }

    with_id_route_parameter

    describe_hook&.call
    parameter(**Api::Schema.archived_parameter)

    get('show archived') do
      response(200, 'successful') do
        schema_for_single
        run_test!
      end
    end
  end

  path "#{base_route}/{id}/recover" do
    with_id_route_parameter
    let(:id) { resolved_instance.id }

    describe_hook&.call

    post('recover (un-delete)') do
      response(204, 'successful') do
        schema nil
        run_test!
      end
    end
  end

  path "#{base_route}/{id}/destroy" do
    with_id_route_parameter
    let(:id) { resolved_instance.id }

    describe_hook&.call

    delete('destroy permanently') do
      response(204, 'successful') do
        schema nil

        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
