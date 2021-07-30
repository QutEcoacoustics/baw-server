# frozen_string_literal: true

# NOTE: this set of specs is intended to be used inside of a request spec file
RSpec.shared_examples 'a route that stores images' do |options|
  # basic integration tests for ActiveStorage images on models
  # Note these tests are for models that use ActiveStorage and NOT paperclip!

  let(:route) { options[:route] }
  let(:current) { send(options[:current]) }
  let(:model_name) { options[:model_name] }
  let(:field_name) { options[:field_name] }
  let(:image) { Fixtures.bowra_image_jpeg }
  let(:mime) { Mime::Type.lookup_by_extension('jpg').to_s }

  resque_log_level :debug

  example 'uploading a new image when the model exists' do
    put "#{route}/#{current.id}", params: {
      "#{model_name}[#{field_name}]" => Rack::Test::UploadedFile.new(image, mime)
    }, headers: form_multipart_headers(owner_token)

    expect_success

    Resque.logger.debug('TEST!')
    Resque.logger.error('TEST!')

    common_expectations
  end

  xexample 'uploading an updated image when the model exists' do
  end

  xexample 'delete an image when the model exists' do
  end

  xexample 'can create a new resource, with multipart JSON payload and image' do
  end

  xexample 'can update a new resource, with multipart JSON payload and image' do
  end

  xexample 'deleting a resource deletes the associated image' do
  end

  xexample 'it rejects images larger than 10MiB' do
  end

  xexample 'it can produce image variants automatically' do
  end

  xexample 'our API includes image urls in payload' do
  end

  def common_expectations
    current.reload
    blob = current.send(field_name)

    aggregate_failures do
      expect(blob).to be_an_instance_of(ActiveStorage::Attached::One)
      expect(blob.attached?).to eq true
      expect(blob.key).not_to be_blank
      expect(blob.signed_id).not_to be_blank
      expect(rails_blob_path(blob, only_path: true)).to start_with('/rails/active_storage/blobs')

      path = ActiveStorage::Blob.service.path_for(blob.key)
      expect(path).to include('public/system/active_storage')
      expect(File.exist?(path)).to eq true
      expect_performed_jobs 1, klass: ActiveStorage::AnalyzeJob
      expect_failed_jobs 0
      expect_enqueued_jobs 0
    end
  end

  around do |example|
    perform_all_jobs_immediately do
      example.run
    end
  end

  after do
    path = ActiveStorage::Blob.service.path_for(current.send(field_name).key)
    expect(File.exist?(path)).to eq true

    # Active record should remove the file when the blob is deleted
    perform_jobs do
      current.destroy!
    end

    expect_jobs_to_be completed: 1, klass: ActiveStorage::PurgeJob

    expect(File.exist?(path)).to eq false
  end
end
