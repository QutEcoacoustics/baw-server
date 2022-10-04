# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id                      :bigint           not null, primary key
#  last_mappings_change_at :datetime
#  last_metadata_review_at :datetime
#  last_upload_at          :datetime
#  mappings                :jsonb
#  name                    :string
#  status                  :string
#  streaming               :boolean
#  upload_password         :string
#  upload_user             :string
#  upload_user_expiry_at   :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  creator_id              :integer
#  project_id              :integer          not null
#  updater_id              :integer
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

  before_save :mark_mappings_change_at
  before_create :set_default_name
  before_update :set_default_name

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

  def mark_mappings_change_at
    self.last_mappings_change_at = Time.now if mappings_changed?
  end

  def set_default_name
    return unless name.blank?

    self.name = "#{created_at.strftime('%B')} #{created_at.day.ordinalize} Upload"
  end

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
    "sftp://#{Settings.upload_service.public_host}:#{Settings.upload_service.sftp_port}"
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

    # remove the leading harvest directory
    path = path.delete_prefix(upload_directory_name)

    # it may or may not have a leading slash, try deleting for consistency
    path = path.delete_prefix('/')

    # choose the path that matched with the most depth
    mappings
      .map { |mapping| [mapping, mapping.match(path)] }
      .select { |_mapping, match| match.some? }
      .max_by { |_mapping, match| match.value! }
      &.first
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

    # @!method uploading?
    state :uploading, enter: [:mark_last_upload_at]
    # @!method uploading?
    state :scanning, enter: [:disable_upload_slot, :scan_upload_directory]
    state :metadata_extraction
    state :metadata_review, enter: [:mark_last_metadata_review_at]
    state :processing
    # @!method complete?
    state :complete, enter: [:close_upload_slot]

    # @!method open_upload
    # @!method open_upload!
    # @!method may_open_upload?
    #   @return [Boolean]
    event :open_upload do
      transitions from: :metadata_review, to: :uploading, guard: :batch_harvest?, after: [:enable_upload_slot]
      transitions from: :new_harvest, to: :uploading,
        after: [:open_upload_slot, :create_harvest_dir, :create_default_mappings]
    end

    # @!method scan
    # @!method scan!
    # @!method may_scan?
    #   @return [Boolean]
    event :scan, guard: :batch_harvest? do
      transitions from: :uploading, to: :scanning
    end

    # @!method extract
    # @!method extract!
    # @!method may_extract?
    #   @return [Boolean]
    event :extract do
      transitions from: :scanning, to: :metadata_extraction
      transitions from: :metadata_review, to: :metadata_extraction, after: [
        :reenqueue_all_harvest_items_for_metadata_extraction
      ]
    end

    # @!method metadata_review
    # @!method metadata_review!
    # @!method may_metadata_review?
    #   @return [Boolean]
    event :metadata_review do
      transitions from: :metadata_extraction, to: :metadata_review, guard: :metadata_extraction_complete?
    end

    # @!method process
    # @!method process!
    # @!method may_process?
    #   @return [Boolean]
    event :process do
      transitions from: :metadata_review, to: :processing, after: [
        :reenqueue_all_harvest_items_for_processing
      ]
    end

    # @!method finish
    # @!method finish!
    # @!method may_finish?
    #   @return [Boolean]
    event :finish do
      transitions from: :processing, to: :complete, guard: :processing_complete?
      transitions from: :uploading, to: :complete, after: [:scan_upload_directory]
    end

    # our state machine helpers allow for automated transitions if there is
    # only one possible transition - otherwise they error.
    # The guard here essentially prioritizes the :finish transition over the
    # :abort transition.
    # @!method abort
    # @!method abort!
    # @!method may_abort?
    #   @return [Boolean]
    event :abort, guard: -> { !may_finish? } do
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

    created_user = BawWorkers::Config.upload_communicator.create_upload_user(
      username: upload_user,
      password: upload_password,
      home_dir: upload_directory,
      permissions:,
      expiry:
    )

    self.upload_user_expiry_at = created_user.expiration_time
  end

  def close_upload_slot
    BawWorkers::Config.upload_communicator.delete_upload_user(username: upload_user)

    self.upload_user = nil
    self.upload_password = nil
    self.upload_user_expiry_at = nil
  end

  def disable_upload_slot
    BawWorkers::Config.upload_communicator.set_user_status(upload_user, enabled: false)
  end

  def enable_upload_slot
    BawWorkers::Config.upload_communicator.set_user_status(upload_user, enabled: true)
  end

  def mark_last_upload_at
    self.last_upload_at = Time.now
  end

  def mark_last_metadata_review_at
    self.last_metadata_review_at = Time.now
  end

  def create_harvest_dir
    # make sure a place exists for files to be uploaded
    upload_directory.mkpath
  end

  def create_default_mappings
    # create a default mapping and folders for each site in this project
    project.sites.each do |site|
      # we expect streaming uploads to be long term - we really don't want to disable uploads
      # on a site rename so we'll use site.id.
      # For batch uploads we expect user interaction; in that case a site name is much friendlier.
      # AT 2022: it is possible for sites names to be non-unique, so we'll use the site.id always in the directory names.
      site_name = streaming_harvest? ? site.id.to_s : site.unique_safe_name

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
      # resets all harvest items statuses to :new and then
      # enqueues a job to enqueue harvest jobs for all items
      BawWorkers::Jobs::Harvest::ReenqueueJob.enqueue!(self, should_harvest: false)
    end
  end

  def reenqueue_all_harvest_items_for_processing
    # re-enqueue all items
    logger.measure_info('Re-enqueue all harvest items for processing') do
      # resets all harvest items statuses to :new and then
      # enqueues a job to enqueue harvest jobs for all items
      BawWorkers::Jobs::Harvest::ReenqueueJob.enqueue!(self, should_harvest: true)
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
    harvest_items.select(:status).distinct.all?(&:metadata_gathered_or_unsuccessful?)
  end

  def processing_complete?
    # have we processed all the items?
    harvest_items.select(:status).distinct.all?(&:terminal_status?)
  end

  # Extends the expiry time of the upload user to 7 days from now,
  # if the current expiry is less than 3.5 days away.
  def extend_upload_user_expiry_if_needed!
    return if streaming_harvest?
    return if complete?
    return if upload_user.nil?

    expiry = BawWorkers::UploadService::Communicator::STANDARD_EXPIRY
    buffer = (expiry / 2).from_now.to_i

    return if ((upload_user_expiry_at&.to_i || 0) - buffer).positive?

    begin
      # SFTPGO accepts a millisecond encoded integer, however it still seems to
      # truncate the value to the nearest second... so we do as well so our tracking
      # field can maintain consistency.
      new_expiry = expiry.from_now.round(0)
      BawWorkers::Config.upload_communicator.set_user_expiration_date(upload_user, expiry: new_expiry)
      self.upload_user_expiry_at = new_expiry
      save!
    rescue Faraday::ConnectionFailed, Net::OpenTimeout, BawWorkers::UploadService::UploadServiceError => e
      Rails.logger.warn('Failed to refresh upload user expiry', exception: e)

      ExceptionNotifier.notify_exception(
        e,
        data: {
          message: "Failed to refresh upload user expiry for harvest #{id}",
          harvest: self
        }
      )
    end
  end

  REPORT_EXPRESSIONS = {
    items_total: Arel.star.count.coalesce(0),
    items_size_bytes: HarvestItem.size_arel.sum.coalesce(0).cast('bigint'),
    items_duration_seconds: HarvestItem.duration_arel.sum.coalesce(0),
    **HarvestItem.counts_by_status_arel('items_'),
    items_invalid_fixable: HarvestItem.invalid_fixable_arel.sum.coalesce(0),
    items_invalid_not_fixable: HarvestItem.invalid_not_fixable_arel.sum.coalesce(0),
    latest_activity_at: HarvestItem.arel_table[:updated_at].maximum
  }.freeze

  # Generates summary statistics for this harvest
  def generate_report
    result = harvest_items.pick_hash(REPORT_EXPRESSIONS)

    last_update = result[:latest_activity_at]
    run_time_seconds = last_update.nil? ? nil : last_update - created_at
    result[:run_time_seconds] = run_time_seconds

    result
  end

  # Define filter api settings
  def self.filter_settings
    filterable_fields = [
      :id, :creator_id, :created_at, :updater_id, :updated_at,
      :streaming, :status, :project_id, :name
    ]
    {
      valid_fields: [*filterable_fields],
      render_fields: [
        *filterable_fields,
        :upload_user,
        :upload_password,
        :upload_url,
        :mappings,
        :report,
        :last_upload_at,
        :last_metadata_review_at,
        :last_mappings_change_at
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
        order_by: :created_at,
        direction: :desc
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
        name: { type: ['null', 'string'] },
        **Api::Schema.updater_and_creator_user_stamps,
        project_id: Api::Schema.id,
        streaming: { type: 'boolean' },
        status: { type: 'string', enum: Harvest.aasm.states.map(&:name) },
        last_upload_at: Api::Schema.date(nullable: true, read_only: true),
        last_metadata_review_at: Api::Schema.date(nullable: true, read_only: true),
        last_mappings_change_at: Api::Schema.date(nullable: true, read_only: true),
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
