# frozen_string_literal: true

# NOTE: this set of specs is intended to be used inside of a request spec file
RSpec.shared_examples 'a route that stores images' do |options|
  # basic integration tests for ActiveStorage images on models
  # Note these tests are for models that use ActiveStorage and NOT paperclip!

  let(:route) { options[:route] }
  let(:current) { send(options[:current]) }
  let(:model_class) { current.class }
  let(:model_name) { options[:model_name] }
  let(:factory_args) { options[:factory_args] }
  let(:field_name) { options[:field_name] }
  let(:image) { Fixtures.bowra_image_jpeg }
  let(:mime) { Mime::Type.lookup_by_extension('jpg').to_s }

  it 'ensures we have patched active storage jobs' do
    expect(ActiveStorage::PurgeJob.ancestors).to include(BawWorkers::ActiveJob::Status)
    expect(ActiveStorage::AnalyzeJob.ancestors).to include(BawWorkers::ActiveJob::Status)
  end

  # Need worker to be able to access database records, can't happen when a transaction is running
  context 'maniuplating blobs', :clean_by_truncation do
    pause_all_jobs

    after do
      key = current.send(field_name)&.key
      if key.nil?
        next
      else
        path = ActiveStorage::Blob.service.path_for(key)
        expect(File.exist?(path)).to eq true

        previously_completed = BawWorkers::ResqueApi.statuses(
          statuses: BawWorkers::ActiveJob::Status::STATUS_COMPLETED,
          of_class: ActiveStorage::PurgeJob
        ).count

        # Active record should remove the file when the blob is deleted
        current.destroy!

        purge_count = @purge_jobs_count || 1
        perform_jobs(count: purge_count)
        expect_jobs_to_be completed: (previously_completed + purge_count), of_class: ActiveStorage::PurgeJob

        expect(File.exist?(path)).to eq false
      end
    end

    example 'uploading a new image when the model exists' do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(image, mime)
      }, **form_multipart_headers(owner_token)

      expect_success
      perform_jobs(count: 1)
      common_expectations
    end

    example 'uploading an updated image when the model exists' do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(image, mime)
      }, **form_multipart_headers(owner_token)

      expect_success
      perform_jobs(count: 1)
      common_expectations

      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)

      expect_success
      perform_jobs(count: 2) # the old file gets purged when a new file is written
      common_expectations(2, 1)
    end

    example 'delete an image when the model exists' do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)

      perform_jobs(count: 1)
      expect_jobs_to_be(completed: 1)
      current.reload
      blob = current.send(field_name)
      expect(blob.attached?).to eq true
      path = ActiveStorage::Blob.service.path_for(blob.key)
      expect(File.exist?(path)).to eq true

      # now delete
      put "#{route}/#{current.id}", params: {
        model_name => { field_name => nil }
      }, **api_with_body_headers(owner_token)

      expect_success

      perform_jobs(count: 1)
      current.reload

      blob = current.send(field_name)
      aggregate_failures do
        expect(blob.attached?).to eq false
        expect(File.exist?(path)).to eq false

        expect_performed_jobs 1, of_class: ActiveStorage::PurgeJob
      end
    end

    example 'can create a new resource, with multipart JSON payload and image' do
      attributes = body_attributes_for(model_name, factory_args: instance_exec(&factory_args))[:region].except(:notes)

      body = {
        region: attributes.merge({
          field_name => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
        })
      }

      post route, params: body, **form_multipart_headers(owner_token)

      expect_success
      id = api_data[:id]
      created = model_class.find(id)
      expect(created).to have_attributes(attributes)

      perform_jobs(count: 1)

      common_expectations(target: created)
    end

    example 'can update a resource, with multipart JSON payload and image' do
      attributes = body_attributes_for(model_name, factory_args: instance_exec(&factory_args))[:region].except(:notes)

      body = {
        region: attributes.merge({
          field_name => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
        })
      }

      put "#{route}/#{current.id}", params: body, **form_multipart_headers(owner_token)

      expect_success
      id = api_data[:id]
      current.reload
      expect(current).to have_attributes(attributes)

      perform_jobs(count: 1)

      common_expectations
    end

    example 'deleting a resource deletes the associated image' do
      # first upload an image
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)
      perform_jobs(count: 1)
      common_expectations

      # now delete

      delete "#{route}/#{current.id}", **api_headers(owner_token)

      expect_success

      perform_jobs(count: 1)
      current.reload

      blob = current.send(field_name)
      aggregate_failures do
        expect(blob.attached?).to eq false
        expect(File.exist?(path)).to eq false

        expect_performed_jobs 1, of_class: ActiveStorage::PurgeJob
      end
    end

    example "it rejects images larger than #{BawApp.attachment_size_limit}" do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.a_very_large_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)

      expect_error(:unprocessable_entity, nil,
        { image: ['Image size 11 MB is greater than 10 MB, try a smaller file'] })
    end

    example 'it can produce image variants automatically' do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)

      perform_jobs(count: 1)
      common_expectations

      expect_json_response
      expect_data_is_hash
      logger.debug('api data', api_data: api_data)
      variant_url = (api_data[:image_urls].select { |i| i[:size] == 'thumb' }).first[:url]
      expected_url_variant = %r{^/rails/active_storage/representations/proxy/.*/#{Fixtures.bowra2_image_jpeg.basename}}
      expect(variant_url).to match expected_url_variant

      # we can fetch the variant on demand
      get variant_url

      expect_success
      expect(response.content_type).to eq('image/jpeg')
      expect(response.content_length).to eq(218_120) # size of variant

      # the variant gets ana analyze job too!?
      expect_enqueued_jobs(1, of_class: ActiveStorage::AnalyzeJob)
      perform_jobs(count: 1)
      expect_enqueued_jobs(0)

      # a purge job will be done for the variant too
      @purge_jobs_count = 2
    end

    example 'our API includes image urls in payload' do
      put "#{route}/#{current.id}", params: {
        "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(Fixtures.bowra2_image_jpeg, mime)
      }, **form_multipart_headers(owner_token)

      # before the analyze job has finished it should still work
      expected_url = %r{^/rails/active_storage/blobs/proxy/.*/#{Fixtures.bowra2_image_jpeg.basename}}
      expected_url_variant = %r{^/rails/active_storage/representations/proxy/.*/#{Fixtures.bowra2_image_jpeg.basename}}

      expect_success
      expect(api_data).to match(a_hash_including(
        image_urls: [
          # width and height are nil because it has not been analyzed yet
          { size: 'original', url: expected_url, width: nil, height: nil },
          { size: 'thumb', url: expected_url_variant, width: 512, height: 512 }
        ]
      ))

      perform_jobs(count: 1)
      common_expectations

      # now fetch the object after the analysis is complete
      get "#{route}/#{current.id}", **api_headers(owner_token)

      expect_success
      # this also tests the urls are stable
      expect(api_data).to match(a_hash_including(
        image_urls: [
          { size: 'original', url: expected_url, width: 2592, height: 1728 },
          { size: 'thumb', url: expected_url_variant, width: 512, height: 512 }
        ]
      ))
    end

    def common_expectations(performed_count = 1, purged_count = 0, target: nil)
      target ||= current
      target.reload
      blob = target.send(field_name)

      aggregate_failures do
        expect(blob).to be_an_instance_of(ActiveStorage::Attached::One)
        expect(blob.attached?).to eq true
        expect(blob.key).not_to be_blank
        expect(blob.signed_id).not_to be_blank
        expect(rails_blob_path(blob, only_path: true)).to start_with('/rails/active_storage/blobs')

        path = ActiveStorage::Blob.service.path_for(blob.key)
        expect(path).to include('public/system/active_storage')
        expect(File.exist?(path)).to eq true
        expect_performed_jobs performed_count, of_class: ActiveStorage::AnalyzeJob
        expect_performed_jobs purged_count, of_class: ActiveStorage::PurgeJob
        expect_failed_jobs 0
        expect_enqueued_jobs 0
      end
    end
  end
end
