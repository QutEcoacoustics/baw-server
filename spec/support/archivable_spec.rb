require 'time'

# things to test for:
#   1 - invalid delete call due to missing id
#   2 - invalid delete call because method is not allowed (either archive or destroy)
#
# Truth table (^ means should have archived header)
# | allow_archive | allow_delete  | 1st call  | 2nd call  | 3rd Call  |
# ---------------------------------------------------------------------
# |     true      |     false     |   204^    |   404     |   404     |
# |     false     |     true      |   204     |   404     |   404     |
# |     true      |     true      |   204^    |   204     |   404     |
# |     false     |     false     |   405     |   405     |   405     |


cases = {
    {allow_archive: true, allow_delete: false} => [:r204a, :r404, :r404],
    {allow_archive: false, allow_delete: true} => [:r204, :r404, :r404],
    {allow_archive: true, allow_delete: true} => [:r204a, :r204, :r404],
    {allow_archive: false, allow_delete: false} => [:r405, :r405, :r405]
}

def delete_api_404_check(
    current_response, item_count_before, item_count_all_before,
    item_count_after, item_count_all_after)

  expect(current_response.status).to eq(404)
  expect(current_response.headers).to_not include(Api::Constants::HTTP_HEADER_ARCHIVED_AT)
  expect(current_response.body).to eq('{"meta":{"status":404,"message":"Not Found","error":{"details":"Could not find the requested item.","info":null}},"data":null}')

  # responds with a not found error that includes the custom error type header
  expect(current_response.headers).to include(Api::Constants::HTTP_HEADER_ERROR_TYPE => 'Active Record/Record Not Found')

  # should NOT destroy or archive any records (count check)
  expect(item_count_after).to eq(item_count_before)
  expect(item_count_all_after).to eq(item_count_all_before)
end

def delete_api_simple_request(request_params, klass)
  item_count_before = klass.count
  item_count_all_before = klass.unscoped.count

  the_response, the_body = make_json_request(request_params)
  current_request = @request # @request is a built-in rspec variable

  item_count_after = klass.count
  item_count_all_after = klass.unscoped.count

  [the_response, the_body, current_request,
   item_count_before, item_count_all_before,
   item_count_after, item_count_all_after]
end

def delete_api_invalid_id_check(klass)
  the_response, _, _,
      item_count_before, item_count_all_before,
      item_count_after, item_count_all_after = delete_api_simple_request(convert_model_for_delete({id: 0}), klass)
  delete_api_404_check(the_response, item_count_before, item_count_all_before,
                       item_count_after, item_count_all_after)
end

# valid and invalid tests, completely self contained
RSpec.shared_examples :a_delete_api_call do |klass, *options|

  allow_archive = options.include?(:allow_archive)
  allow_delete = options.include?(:allow_delete)
  selected_cases = cases[{allow_archive: allow_archive, allow_delete: allow_delete}]

  let(:model_symbol) do
    klass.name.underscore.to_sym
  end

  context "delete api call to #{klass} testing #{options.join(', ')}" do

    it "succeeds for cases #{selected_cases.join(', ')}" do



      # create the item to test
      if defined?(delete_api_model)
        item = delete_api_model
      else
        # first db seed to make the count tests more understandable
        create(model_symbol)

        item = create(model_symbol)

        # second db seed item
        create(model_symbol)
      end



      # check request with invalid id
      delete_api_invalid_id_check(klass)

      # check request with no id
      expect {
        _, _ = make_json_request(convert_model_for_delete({}))
      }.to raise_error(ActionController::UrlGenerationError,
                       /No route matches \{:action=>"destroy", :controller=>".*", :format=>"json"\}/)

      # make sure model has correct fields
      expect(allow_archive).to eq(item.respond_to?('deleter_id')), "should #{'not' unless allow_archive } have deleted_id attribute"
      expect(allow_archive).to eq(item.respond_to?('deleted_at')), "should #{'not' unless allow_archive } have deleted_at attribute"

      # simulate multiple delete api calls, checking the state after each
      # call delete: once, twice, three times
      [1, 2, 3].each { |call|

        current_case = selected_cases[call-1]
        current_message = "#{ActiveSupport::Inflector.ordinalize(call)} delete api call (expected response: #{current_case})"
        p "#{klass}: #{current_message}"

        item_count_before = klass.count
        item_count_all_before = klass.unscoped.count

        current_response, current_body = make_json_request(convert_model_for_delete({id: item.id}))
        current_request = @request # @request is a built-in rspec variable

        item_count_after = klass.count
        item_count_all_after = klass.unscoped.count

        # the rest of the tests then test the result (either response or exception)

        current_archived_at = nil
        if current_response.headers.include?(Api::Constants::HTTP_HEADER_ARCHIVED_AT)
          current_archived_at = Time.httpdate(current_response.headers[Api::Constants::HTTP_HEADER_ARCHIVED_AT])
        end

        ##
        #
        # tests for current_case
        #
        ##

        # All
        expect(current_response.content_type).to eq('application/json')

        # Archive
        if current_case == :r204a
          expect(current_response.status).to eq(204)
          expect(current_response.headers).to include(Api::Constants::HTTP_HEADER_ARCHIVED_AT)
          #expect(current_archived_at).to be_within(1.second).of(Time.zone.now)
          expect(current_response.body).to eq('{"meta":{"status":204,"message":"No Content"},"data":null}')

          expect(item_count_after).to eq(item_count_before - 1)
          expect(item_count_all_after).to eq(item_count_all_before)

          # should not be returned by default when a query (model) would include it
          expect(klass.where(id: item.id).all).to be_empty

          # should archive the correct record by updating the deleted_at
          if klass.respond_to?('with_deleted')
            item_from_db = klass.with_deleted.find_by_id(item.id)
          else
            item_from_db = nil
          end

          if item_from_db && item_from_db.respond_to?('deleted_at')
            expect(item_from_db.deleted_at).to_not be_blank, "expected #{item_from_db} to have deleted_at set, but it was not"
          end

          # should archive the correct record by updating the deleter_id
          if klass.respond_to?('with_deleted')
            item_from_db = klass.with_deleted.find_by_id(item.id)
          else
            item_from_db = nil
          end

          if item_from_db.respond_to?('deleter_id')
            expect(item_from_db.deleter_id).to_not be_blank, "expected #{item_from_db.to_json} to have deleter_id set, but it was not"
          end
        end

        # Delete
        if current_case == :r204
          expect(current_response.status).to eq(204)
          expect(current_response.headers).to_not include(Api::Constants::HTTP_HEADER_ARCHIVED_AT)
          expect(current_response.body).to eq('{"meta":{"status":204,"message":"No Content"},"data":null}')

          # check the expected count of items match
          if allow_archive
            expect(item_count_after).to eq(item_count_before)
          else
            expect(item_count_after).to eq(item_count_before - 1)
          end
          expect(item_count_all_after).to eq(item_count_all_before - 1)

          # should destroy the correct record in the database
          expect(klass.find_by_id(item.id)).to be_nil

          # should (really really) destroy the correct record in the database
          expect(klass.unscoped.find_by_id(item.id)).to be_nil
        end

        # Not Found
        if current_case == :r404
          delete_api_404_check(current_response, item_count_before, item_count_all_before,
                               item_count_after, item_count_all_after)

          # item should (appear to) not exist in the database
          expect(klass.find_by_id(item.id)).to be_nil

          if allow_delete
            # item should (really really) not exist in the database
            expect(klass.unscoped.find_by_id(item.id)).to be_nil
          else
            expect(klass.unscoped.find_by_id(item.id)).to_not be_nil
          end
        end

        # Method Not Allowed
        if current_case == :r405
          expect(current_response.status).to eq(405)
          expect(current_response.headers).to_not include(Api::Constants::HTTP_HEADER_ARCHIVED_AT)

          # should NOT destroy the record (existence check)
          expect(klass.where(id: item.id).first).to_not be_blank

          # should NOT destroy or archive the record (count check)
          expect(item_count_after).to eq(item_count_before)
          expect(item_count_all_after).to eq(item_count_all_before)
        end

      }
    end
  end
end



