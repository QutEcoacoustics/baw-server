require 'spec_helper'

ARCHIVED_HEADER = 'X-Archived-At'

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

# valid and invalid tests, completely self contained
shared_examples :a_delete_api_call do |klass, *options|

  allow_archive = options.include?(:allow_archive)
  allow_delete = options.include?(:allow_delete)

  let(:model_symbol) do
    klass.name.underscore.to_sym
  end

  context 'invalid id test' do
    before(:each) do
      @item = create(model_symbol)
      @item_count_before = klass.unscoped.count
    end
    # tests 1st point
    it 'should raise the expected error if the id does NOT exist' do
      expect {
        json(convert_model_for_delete({id: -30}))
      }.to raise_error(ActiveRecord::RecordNotFound)

      klass.unscoped.count.should == @item_count_before
      response.body.should be_blank
    end

    it 'should not do anything if no id is specified' do
      expect {
        # also tests for sending empty parameters
        json(convert_model_for_delete({}))
      }.to raise_error(ActionController::RoutingError)

      response.body.should be_blank
      klass.unscoped.count.should == @item_count_before
    end
  end

  context 'valid controllers and their models' do
    before(:each) do
      @item = build(model_symbol)
    end
    it "should #{'not' unless allow_archive } have deleted_id attribute" do
      @item.respond_to?('deleter_id').should == allow_archive
    end
    it "should #{'not' unless allow_archive } have deleted_at attribute" do
      @item.respond_to?('deleted_at').should == allow_archive
    end
  end


  # simulate multiple delete api calls, checking the state after each
  [1, 2, 3].each { |call|

    expected_response = (cases[{allow_archive: allow_archive, allow_delete: allow_delete}])[call-1]

    # call delete, once, twice, three times
    context "#{ActiveSupport::Inflector.ordinalize(call)} delete api call (expected response: #{expected_response})" do

      before(:each) do
        # seed to ensure at least one other item, makes the count tests more understandable
        create(model_symbol)

        @item = create(model_symbol)
        @item_count_before = klass.count

        # if exception thrown it is not always assigned
        @response_body = nil

        index = 0
        while index < call do
          index = index + 1
          begin
            @response_body = json(convert_model_for_delete({id: @item.id}))
          rescue ActiveRecord::RecordNotFound => e404
            @exception = e404
          end
        end

        @item_count_after = klass.unscoped.count
        # the rest of the tests then test the result (either response or exception)
      end

      ##
      #
      # tests for expected_response
      #
      ##

      ##
      #   Destroyed
      ##
      if expected_response == :r204
        it { should respond_with(:no_content) }
        it { should respond_with_content_type(:json) }
        it 'should destroy the correct record in the database' do
          klass.find_by_id(@item[:id]).should == nil
        end
        it 'should (really really) destroy the correct record in the database' do
          klass.unscoped.find_by_id(@item[:id]).should == nil
        end
      end

      ##
      #   Archived
      ##
      if expected_response == :r204a
        it { should respond_with(:no_content) }
        it { should respond_with_content_type(:json) }

        it 'should return the archived_at date as a header' do
          has_header = @response.headers.include?(ARCHIVED_HEADER)
          has_header.should be_true
        end
        it 'should archive the correct record by updating the deleted_at' do
          if klass.respond_to?('with_deleted')
            item_from_db = klass.with_deleted.find_by_id(@item[:id])
          else
            item_from_db = nil
          end
          if item_from_db && item_from_db.respond_to?('deleted_at')
            item_from_db.deleted_at.should_not be_blank
          end
        end
        it 'should archive the correct record by updating the deleter_id' do
          if klass.respond_to?('with_deleted')
            item_from_db = klass.with_deleted.find_by_id(@item[:id])
          else
            item_from_db = nil
          end
          if item_from_db.respond_to?('deleter_id')
            item_from_db.deleter_id.should_not be_blank
          end
        end
        it 'should not be returned by default when a query (model) would include it' do
          klass.where(:id => @item[:id]).all.should be_empty
        end
        it 'should not be returned by default when a request (controller) is made for it\'s id' do
          expect {
            @response_body2 = json({get: :show, id: @item.id})
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      ##
      #   Not found
      ##
      if expected_response == :r404
        it 'should have populated the exception object that represents a 404' do
          @exception.should be_an_instance_of(ActiveRecord::RecordNotFound)
        end
      end

      ##
      #   Not allowed
      ##
      if expected_response == :r405
        it { should respond_with(:method_not_allowed) }
        it { should respond_with_content_type(:json) }
        it 'should NOT destroy the record (existence check)' do
          klass.where(:id => @item[:id]).first.should_not be_nil
        end
      end

      ##
      #   ALL Invalid responses
      ##
      if expected_response == :r405 || expected_response == :r404
        it 'should NOT destroy the record (count check)' do
          klass.unscoped.count.should == @item_count_after
        end
      end

      ##
      #   ANY response other than  r204a (archived)
      ##
      if expected_response != :r204a
        it 'should NOT return the archived_at date as a header' do
          has_header = @response.headers.include?(ARCHIVED_HEADER)
          has_header.should be_false
        end
      end

      ##
      #   ANY response other than  404 (i.e. not an exception)
      #   There is no content type given
      ##
      #if expected_response != :r404
      #it { should respond_with_content_type(:json) }
      #end

      ##
      #   Should happen no matter what
      ##
      if true
        it 'should be empty' do
          @response.body.should be_blank
        end
      end

    end
  }
end



