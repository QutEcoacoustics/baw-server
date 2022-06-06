# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id               :bigint           not null, primary key
#  last_upload_date :datetime
#  mappings         :jsonb
#  status           :string
#  streaming        :boolean
#  upload_password  :string
#  upload_user      :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  creator_id       :integer
#  project_id       :integer          not null
#  updater_id       :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
class Harvest < ApplicationRecord
  include AASM
  include AasmHelpers
  HARVEST_FOLDER_PREFIX = 'harvest_'
  HARVEST_ID_FROM_FOLDER_REGEX = %r{/#{HARVEST_FOLDER_PREFIX}(\d+)/}

  has_many :harvest_items, inverse_of: :harvest

  belongs_to :project, inverse_of: :harvests

  belongs_to :creator, class_name: User.name, foreign_key: :creator_id, inverse_of: :created_harvests
  belongs_to :updater, class_name: User.name, foreign_key: :updater_id, inverse_of: :updated_harvests, optional: true

  validates :project, presence: true
  validate :validate_uploads_enabled
  validate :validate_site_mappings_exist
  validate :validate_mapping_path_uniqueness

  # @!attribute [rw] mappings
  #   @return [Array<BawWorkers::Jobs::Harvest::Mapping>]
  attribute :mappings, ::BawWorkers::ActiveRecord::Type::ArrayOfDomainModelAsJson.new(
    target_class: ::BawWorkers::Jobs::Harvest::Mapping
  )

  # @return [Boolean]
  def uploads_enabled?
    project&.allow_audio_upload == true
  end

  def validate_uploads_enabled
    return if uploads_enabled?

    errors.add(:project, 'A harvest cannot be created unless its parent project has enabled audio upload')
  end

  def validate_site_mappings_exist
    return if mappings.blank?

    mappings.each do |mapping|
      next unless mapping.site_id.present?

      next if Site.exists?(mapping.site_id)

      errors.add(:mappings, "Site '#{mapping.site_id}' does not exist for mapping '#{mapping.path}'")
    end
  end

  def validate_mapping_path_uniqueness
    return if mappings.blank?

    duplicates = mappings.group_by(&:path).select { |_, v| v.size > 1 }

    duplicates.each do |path, _mappings|
      errors.add(:mappings, "Duplicate path in mappings: '#{path}'")
    end
  end

  # @return [String]
  def upload_url
    "sftp://#{Settings.upload_service.host}:#{Settings.upload_service.sftp_port}"
  end

  # @return [Boolean]
  def streaming_harvest?
    streaming
  end

  # @return [Boolean]
  def batch_harvest?
    !streaming
  end

  # The fragment of the path used to store files related to this harvest.
  # @see #upload_directory
  # @return [String]
  def upload_directory_name
    HARVEST_FOLDER_PREFIX + id.to_s
  end

  # The absolute path to the directory used to store files related to this harvest.
  # @return [Pathname]
  def upload_directory
    Settings.root_to_do_path / upload_directory_name
  end

  # Joins a virtual path (scoped to within the harvest directory)
  # to the upload_directory_name to create a path relative
  # to the harvester_to_do directory.
  # e.g. a/123.mp3 --> /harvest_1/a/123.mp3
  # @return [String]
  def harvester_relative_path(virtual_path)
    File.join(upload_directory_name, virtual_path)
  end

  # Given a path (such as reported by the sftp go web hook)
  # to a file, determine if it is a harvest directory and if it is
  # extract the id and load the Harvest object
  # @param path [String] an **absolute** path to an uploaded file
  # @return [nil,Harvest]
  def self.fetch_harvest_from_absolute_path(path)
    # path: "/data/test/harvester_to_do/harvest_1/test-audio-mono.ogg"
    # virtual path: "/test-audio-mono.ogg"
    return nil if path.blank?

    return nil unless path.include?(HARVEST_FOLDER_PREFIX)

    result = path.match(HARVEST_ID_FROM_FOLDER_REGEX)
    return nil if result.nil?

    id = result[1]

    Harvest.find_by(id:)
  end

  # @param path [String] assumed to be relative to the harvester_to_do directory
  #     e.g. harvest_1/a/12.mp3
  # Note: leading slash should be omitted, and we expect a file path
  # @return [Boolean,nil]
  def path_within_harvest_dir(path)
    #raise ArgumentError, 'path cannot be a root path' if path.start_with?('/')
    path = path.delete_prefix('/')

    root = "#{upload_directory_name}/"
    path.start_with?(root)
  end

  # Queries mapping for any information about a path
  # @param path [String] assumed to be relative to the harvester_to_do directory
  #     e.g. harvest_1/a/12.mp
  # Note: leading slash should be omitted, and we expect a file path
  # @return [BawWorkers::Jobs::Harvest::Mapping,nil]
  def find_mapping_for_path(path)
    raise "Path #{path} does not belong to this harvest #{root}" unless path_within_harvest_dir(path)

    # trim the path
    path = File.dirname(path).to_s

    # remove the leading harvest direcotry
    path = path.delete_prefix(upload_directory_name)

    # it may or may not have a leading slash, try deleting for consistency
    path = path.delete_prefix('/')

    mappings
      .select { |mapping| mapping.match(path) }
      # choose the path that matched with the most depth
      .max_by { |m| m.path.size }
  end

  # We have two methods of uploads:
  # 1. batch uploads
  # 2. streaming uploads
  #
  # The batch method is most common and is a semi-supervised process that involves a human checking
  # the workflow at various stages.
  #
  # The streaming method is used for remote devices. They just pump new files and we harvest as we go.
  # Any errors are just ignored. In the streaming mode the only valid states are :new_harvest, :uploading,
  # and :completed.
  #
  # State transition map:
  #                     |-------------------------------(streaming only)--------------------------------|
  #                     ↑                                                                               ↓
  # :new_harvest → :uploading → :scanning → :metadata_extraction → :metadata_review → :processing → :complete
  #                     ↑                            ↑                      ↓
  #                     |---------------------------------------------------|
  #
  aasm column: :status, no_direct_assignment: true, whiny_persistence: true, logger: SemanticLogger[Harvest] do
    state :new_harvest, initial: true

    state :uploading, enter: [:mark_last_upload_date]
    state :scanning, enter: [:disable_upload_slot, :scan_upload_directory]
    state :metadata_extraction
    state :metadata_review
    state :processing
    # @!method complete?
    state :complete, enter: [:close_upload_slot]

    event :open_upload do
      transitions from: :metadata_review, to: :uploading, guard: :batch_harvest?, after: [:enable_upload_slot]
      transitions from: :new_harvest, to: :uploading, after: [:open_upload_slot, :create_default_mappings]
    end

    event :scan, guard: :batch_harvest? do
      transitions from: :uploading, to: :scanning
    end

    event :extract do
      transitions from: :scanning, to: :metadata_extraction
      transitions from: :metadata_review, to: :metadata_extraction, after: [
        :reenqueue_all_harvest_items_for_metadata_extraction
      ]
    end

    event :metadata_review do
      transitions from: :metadata_extraction, to: :metadata_review, guard: :metadata_extraction_complete?
    end

    event :process do
      transitions from: :metadata_review, to: :processing, after: [
        :reenqueue_all_harvest_items_for_processing
      ]
    end

    event :finish do
      transitions from: :processing, to: :complete, guard: :processing_complete?
      transitions from: :streaming, to: :complete
    end

    event :abort do
      transitions to: :complete
    end
  end

  def open_upload_slot
    self.upload_user = "#{creator.safe_user_name}_#{id}"
    self.upload_password = User.generate_unique_secure_token

    if streaming_harvest?
      BawWorkers::UploadService::Communicator::NO_DIRECTORY_CHANGES_PERMISSIONS
    else
      BawWorkers::UploadService::Communicator::STANDARD_PERMISSIONS
    end => permissions

    # either ? never expires : use default (7 days)
    expiry = streaming_harvest? ? Time.at(0) : nil

    BawWorkers::Config.upload_communicator.create_upload_user(
      username: upload_user,
      password: upload_password,
      home_dir: upload_directory,
      permissions:,
      expiry:
    )
  end

  def close_upload_slot
    BawWorkers::Config.upload_communicator.delete_upload_user(username: upload_user)

    self.upload_user = nil
    self.upload_password = nil
  end

  def disable_upload_slot
    BawWorkers::Config.upload_communicator.set_user_status(upload_user, enabled: false)
  end

  def enable_upload_slot
    BawWorkers::Config.upload_communicator.set_user_status(upload_user, enabled: true)
  end

  def mark_last_upload_date
    self.last_upload_date = Time.now
  end

  def create_default_mappings
    # create a default mapping and folders for each site in this project
    project.sites.each do |site|
      # we expect streaming uploads to be long term - we really don't want to disable uploads
      # on a site rename so we'll use site.id.
      # For batch uploads we expect user interaction; in that case a site name is much friendlier.
      site_name = streaming_harvest? ? site.id.to_s : site.safe_name
      real_path = upload_directory / site_name

      real_path.mkpath

      mappings << BawWorkers::Jobs::Harvest::Mapping.new(
        path: site_name,
        site_id: site.id,
        utc_offset: nil,
        recursive: true
      )
    end
  end

  def scan_upload_directory
    BawWorkers::Jobs::Harvest::ScanJob.perform_later!(id)
  end

  def reenqueue_all_harvest_items_for_metadata_extraction
    # re-enqueue all items
    logger.measure_info('Re-enqueue all harvest items for metadata extraction') do
      # potentially large query, don't pull back the file info column which could be huge
      harvest_items.select(:id, :status, :path).each do |item|
        BawWorkers::Jobs::Harvest::HarvestJob.enqueue(item, should_harvest: false)
      end
    end
  end

  def reenqueue_all_harvest_items_for_processing
    # re-enqueue all items
    logger.measure_info('Re-enqueue all harvest items for processing') do
      # potentially large query, don't pull back the file info column which could be huge
      harvest_items.select(:id, :status, :path).each do |item|
        BawWorkers::Jobs::Harvest::HarvestJob.enqueue(item, should_harvest: true)
      end
    end
  end

  def update_allowed?
    # if we're in a state where we are waiting for a computation to finish, we can't
    # allow a client to transition us to a different state
    !(scanning? || metadata_extraction? || processing?)
  end

  # transitions from either metadata_extraction or processing
  # to metadata_review or review id the respective processing step is complete
  def transition_from_computing_to_review_if_needed!
    return unless metadata_extraction? || processing?

    return metadata_review! if may_metadata_review?

    return finish! if may_finish?
  end

  def metadata_extraction_complete?
    # have we gathered all the metadata for each item?
    harvest_items.select(:status).distinct.all?(&:metadata_gathered?)
  end

  def processing_complete?
    # have we processed all the items?
    harvest_items.select(:status).distinct.all?(&:terminal_status?)
  end

  # Generates summary statistics for this harvest
  def generate_report
    last_update = harvest_items.order(updated_at: :desc).select(:updated_at)&.first&.updated_at
    run_time_seconds = last_update.nil? ? nil : last_update - created_at

    {
      items_total: harvest_items.count,
      items_size_bytes: harvest_items.sum(HarvestItem.size_arel),
      items_duration_seconds: harvest_items.sum(HarvestItem.duration_arel),
      **HarvestItem.counts_by_status(harvest_items).transform_keys { |k| "items_#{k}" },

      items_invalid_fixable: harvest_items.sum(HarvestItem.invalid_fixable_arel),
      items_invalid_not_fixable: harvest_items.sum(HarvestItem.invalid_not_fixable_arel),

      latest_activity: last_update,
      run_time_seconds:
    }
  end

  # Define filter api settings
  def self.filter_settings
    filterable_fields = [:id, :creator_id, :created_at, :updater_id, :updated_at, :streaming, :status, :project_id]
    {
      valid_fields: [*filterable_fields],
      render_fields: [
        *filterable_fields,
        :upload_user,
        :upload_password,
        :upload_url,
        :mappings,
        :report
      ],
      text_fields: [],
      custom_fields2: {
        upload_url: {
          # we don't really need :id to calculate this custom field but if the array is empty
          # the field gets ignored
          query_attributes: [:id],
          transform: ->(item) { item&.upload_url },
          arel: nil,
          type: :string
        },
        report: {
          query_attributes: [:id],
          transform: ->(item) { item.generate_report },
          arel: nil,
          type: :array
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           project_id: true,
                           streaming: false
                         }
                       },
      controller: :harvests,
      action: :filter,
      defaults: {
        order_by: :id,
        direction: :asc
      },
      valid_associations: [
        {
          join: Project,
          on: Harvest.arel_table[:project_id].eq(Project.arel_table[:id]),
          available: true
        },
        {
          join: HarvestItem,
          on: HarvestItem.arel_table[:harvest_id].eq(Harvest.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        **Api::Schema.updater_and_creator_user_stamps,
        project_id: Api::Schema.id,
        streaming: { type: 'boolean' },
        status: { type: 'string', enum: Harvest.aasm.states.map(&:name) },
        upload_user: { type: ['null', 'string'], readOnly: true },
        upload_password: { type: ['null', 'string'], readOnly: true },
        upload_url: { type: ['null', 'string'], format: 'url', readOnly: true },
        mappings: {
          type: ['array', 'null'],
          items: {
            type: 'object',
            properties: {
              path: { type: 'string' },
              site_id: { type: Api::Schema.id(nullable: true) }
            }
          }
        },
        report: {
          type: 'object',
          readOnly: true,
          properties: {
            items_total: { type: 'integer' },
            items_size_bytes: { type: 'integer' },
            items_duration_seconds: { type: 'number' },
            items_invalid_fixable: { type: 'integer' },
            items_invalid_not_fixable: { type: 'integer' },
            items_new: { type: 'integer' },
            items_metadata_gathered: { type: 'integer' },
            items_failed: { type: 'integer' },
            items_completed: { type: 'integer' },
            items_errored: { type: 'integer' },
            latest_activity_at: { type: ['null', 'string'], format: 'date-time' },
            run_time_seconds: { type: ['null', 'number'] }
          }
        }

      },
      required: [
        :id,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :project_id,
        :status,
        :streaming,
        :upload_user,
        :upload_password,
        :upload_url,
        :mappings,
        :report
      ]
    }.freeze
  end
end
