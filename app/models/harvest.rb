# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id              :bigint           not null, primary key
#  mappings        :jsonb
#  status          :string
#  streaming       :boolean
#  upload_password :string
#  upload_user     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :integer
#  project_id      :integer          not null
#  updater_id      :integer
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
    BawWorkers::Jobs::Harvest::Enqueue.root_to_do_path / upload_directory_name
  end

  # Joins a virtual path (scoped to within the harvest directory)
  # to the upload_directory_name to create a path relative
  # to the harvester_to_do directory.
  # @return [String]
  def harvester_relative_path(virtual_path)
    File.join(upload_directory, virtual_path)
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
  #     e.g. harvest_1/a/12.mp
  # Note: leading slash should be omitted, and we expect a file path
  # @return [Boolean,nil]
  def path_within_harvest_dir(path)
    raise ArgumentError, 'path cannot be a root path' if path.start_with?('/')

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
  #                     |-------------------------------(streaming only)------------------------------|
  #                     ↑                                                                             ↓
  # :new_harvest → :uploading → :metadata_extraction → :metadata_review → :processing → :review → :complete
  #                     ↑                                       ↓                          ↓
  #                     |------------------------------------------------------------------|
  #
  aasm column: :status, no_direct_assignment: true, whiny_persistence: true do
    state :new_harvest, initial: true

    state :uploading, enter: :open_upload_slot
    state :metadata_extraction
    state :metadata_review
    state :processing
    state :review
    # @!method complete?
    state :complete

    event :open_upload do
      transitions from: :metadata_review, to: :uploading, guard: :batch_harvest?
      transitions from: :review, to: :uploading, guard: :batch_harvest?
      transitions from: :new_harvest, to: :uploading
    end

    event :extract do
      transitions from: :uploading, to: :metadata_extraction
    end

    event :metadata_review do
      transitions from: :metadata_extraction, to: :metadata_review, guard: :metadata_extraction_complete?
    end

    event :process do
      transitions from: :metadata_review, to: :processing
    end

    event :review do
      transitions from: :processing, to: [:review], guard: :processing_complete?
    end

    event :finish do
      transitions from: :review, to: :complete, guard: :batch_harvest?
      transitions from: :streaming, to: :complete
    end

    event :abort do
      transitions to: :complete
    end
  end

  def open_upload_slot
    self.upload_user = "#{creator.safe_user_name}_#{id}"
    self.upload_password = User.generate_unique_secure_token
    BawWorkers::Config.upload_communicator.create_upload_user(
      username: upload_user,
      password: upload_password,
      home_dir: upload_directory,
      permissions: BawWorkers::UploadService::Communicator::STANDARD_PERMISSIONS
    )
  end

  def update_allowed?
    # if we're in a state where we are waiting for a computation to finish, we can't
    # allow a client to transition us to a different state
    !(metadata_extraction? || processing?)
  end

  # transitions from either metadata_extraction or processing
  # to metadata_review or review id the respective processing step is complete
  def transition_from_computing_to_review_if_needed!
    return unless metadata_extraction? || processing?

    return metadata_review! if may_metadata_review?

    return review! if may_review?
  end

  def metadata_extraction_complete?
    # have we gathered all the metadata for each item?
    harvest_items.all?(&:metadata_gathered?)
  end

  def processing_complete?
    # have we processed all the items?
    harvest_items.all?(&:terminal_status?)
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
          # TODO: incomplete
          query_attributes: [:id],
          transform: ->(_item) { {} }, #placeholder
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
        status: { type: 'string' },
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
          readOnly: true
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
