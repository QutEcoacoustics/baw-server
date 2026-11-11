# frozen_string_literal: true

# == Schema Information
#
# Table name: exports
#
#  id                                                     :bigint           not null, primary key
#  download_count                                         :integer          default(0)
#  error(User visible error message if the export failed) :text
#  expires_at                                             :datetime
#  export_type                                            :string(16)       not null
#  filter                                                 :jsonb            not null
#  finished_at                                            :datetime
#  name                                                   :string
#  obfuscate_locations                                    :boolean
#  options(Additional options for the export)             :jsonb
#  purged                                                 :boolean
#  started_at                                             :datetime
#  status                                                 :enum             default("pending"), not null
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#  creator_id                                             :bigint           not null
#  project_id                                             :bigint           not null
#
# Indexes
#
#  index_exports_on_creator_id  (creator_id)
#  index_exports_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#
class Export < ApplicationRecord
  belongs_to :creator, class_name: 'User', inverse_of: :created_exports
  belongs_to :project, inverse_of: :exports

  has_one_attached :file

  STATUS_PENDING = 'pending'
  STATUS_QUEUED  = 'queued'
  STATUS_WORKING = 'working'
  STATUS_READY   = 'ready'
  STATUS_FAILED  = 'failed'

  STATUS_ENUM = {
    STATUS_PENDING => STATUS_PENDING,
    STATUS_QUEUED => STATUS_QUEUED,
    STATUS_WORKING => STATUS_WORKING,
    STATUS_READY => STATUS_READY,
    STATUS_FAILED => STATUS_FAILED
  }.freeze

  enum :status, STATUS_ENUM, prefix: :status, validate: true, instance_methods: false

  def status_ready? = status == STATUS_READY
  def status_failed? = status == STATUS_FAILED
  def status_queued? = status == STATUS_QUEUED
  def status_working? = status == STATUS_WORKING

  include StateMachine
  extend Schema

  EXPORT_TYPE_CAMTRAP_DP = 'camtrap_dp'

  EXPORT_TYPE_ENUM = {
    EXPORT_TYPE_CAMTRAP_DP => EXPORT_TYPE_CAMTRAP_DP
  }.freeze

  enum :export_type, EXPORT_TYPE_ENUM, prefix: :export_type, validate: true

  validate :attachment_acceptable, if: -> { file.attached? }
  validate :validate_options_camtrap_dp, on: :create, if: :export_type_camtrap_dp?
  validate :validate_obfuscate_locations, on: :create, if: -> { obfuscate_locations == false }

  validates :name, length: { minimum: 2, maximum: 255 }
  validates :export_type, presence: true

  validate :filter_hash_is_valid, on: :create
  validates :started_at, :finished_at,
    allow_blank: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }

  # Scope to order exports by file size in descending order (largest first).
  scope :largest_first, lambda {
    joins(:file_blob).order(ActiveStorage::Blob.arel_table[:byte_size].desc)
  }

  # Scope to filter exports by file size greater than the given number of bytes.
  scope :larger_than, lambda { |bytes|
    joins(:file_blob).where(ActiveStorage::Blob.arel_table[:byte_size].gt(bytes))
  }

  # Scope to exports whose expires_at is in the past.
  scope :expired, -> { where(arel_table[:expires_at].lt(Time.zone.now)) }

  # Raised by a generator for permanent, safe-to-show errors.
  class UserFacingError < StandardError; end

  # Run the generator for the export, handling file attachment and state transitions.
  #
  # @param (see #claim_for_generation! resume)
  # @return [void]
  def generate(resume: false)
    return unless claim_for_generation!(resume:)

    build_generator.call do |io, filename, content_type|
      file.attach(io:, filename:, content_type:)
    end

    ready!
    send_completed_email
  rescue UserFacingError => e
    record_failure!(e.message)
  rescue StandardError
    # For any unexpected errors, record a user-facing generic message, then re-raise.
    # For a background job, re-raise is handled by ApplicationJob's `discard_on(StandardError)`,
    # which logs the real error and mails an error notification.
    record_failure!('An unexpected error occurred while generating the export.')
    raise
  end

  # Enqueue the export for background processing.
  #
  # @raise [InvalidTransition] if the export is not pending, failed, or purged.
  # @raise [BawWorkers::ActiveJob::EnqueueError] if the job is not accepted; the export is left unchanged.
  def enqueue!
    # Validates against the locked, reloaded row and rolls back `queued` if the job is rejected.
    with_lock do
      queued!
      BawWorkers::Jobs::Export::ExportJob.enqueue(self)
    end
  end

  # Removes the attached file and marks the export purged.
  #
  # @raise [InvalidTransition] if the export is queued or being generated.
  # @return [void]
  def purge!
    with_lock do
      next if purged?

      raise InvalidTransition, "Cannot purge an export that is #{status}" if status_queued? || status_working?

      update!(purged: true)
      file&.purge
    end
  end

  # Whether the creator's *current* permissions still allow the export to be downloaded.
  # Permissions can be revoked after an export is created, so this is re-checked at download.
  # - the creator must still be a reader (or higher) of the project
  # - an export with unobfuscated locations also requires the creator to still be an owner
  # @return [Boolean]
  def creator_can_download?
    return false if project.blank?

    return true if creator_is_owner?
    return false if obfuscate_locations == false

    Access::Core.can_any?(creator, Access::Permission::READER, project)
  end

  def self.filter_settings
    fields = [
      :id, :download_count, :error, :expires_at, :export_type, :filter,
      :finished_at, :name, :obfuscate_locations, :options, :purged, :started_at,
      :status, :created_at, :updated_at, :creator_id, :project_id
    ]

    {
      valid_fields: fields,
      render_fields: fields,
      text_fields: [],
      new_spec_fields: lambda { |_user|
        {
          export_type: nil,
          name: nil,
          obfuscate_locations: nil,
          project_id: nil,
          filter: nil,
          options: nil
        }
      },
      controller: :exports,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :desc
      }
    }
  end

  private

  # A failure to enqueue the email must not mark an export that is already ready as failed.
  def send_completed_email
    ExportMailer.completed_export_message(self).deliver_later
  rescue StandardError => e
    logger.error('Failed to enqueue the completed export email', e)
  end

  # Claims the export for generation, transitioning it to `working` if successful.
  #
  # @param resume [Boolean] when true, an export with status `working` can be
  #   claimed for generation (used on job retries). When false (default), an
  #   export that is already `working` is skipped.
  # @raise [UserFacingError] if the project is missing, or if locations are unobfuscated
  #   and the creator no longer owns the project.
  # @return [Boolean] true if the export is claimed for generation, false if it is not.
  def claim_for_generation!(resume:)
    with_lock do
      next false if status_ready? || (status_working? && !resume)

      # An export row may exist without a project, but it cannot be generated without one.
      raise UserFacingError, 'project must be present' if project.blank?

      if obfuscate_locations == false && !creator_is_owner?
        raise UserFacingError, 'obfuscate_locations can only be false while the creator owns the project'
      end

      working!(resume:)
      true
    end
  end

  # Each export type has a generator named after it, e.g. camtrap_dp -> Export::CamtrapDpGenerator,
  # implementing the interface documented on CamtrapDpGenerator.
  def build_generator
    raise "Unsupported export type: #{export_type}" unless self.class.export_types.key?(export_type)

    self.class.const_get("#{export_type.camelize}Generator", false).new(self)
  end

  def validate_options_camtrap_dp
    result = CamtrapDpOptionsContract.new.call(options || {})
    return if result.success?

    result.errors.each do |error|
      errors.add(:options, "#{error.path.join('.')} #{error.text}")
    end
  end

  def attachment_acceptable
    return if file.content_type == 'application/zip'

    errors.add(:file, 'must be a zip file')
  end

  def validate_obfuscate_locations
    return if project.present? && creator_is_owner?

    errors.add(:obfuscate_locations, 'can only be set to false by the project owner')
  end

  def creator_is_owner?
    Access::Core.can_any?(creator, Access::Permission::OWNER, project)
  end

  def filter_hash_is_valid
    return errors.add(:filter, 'cannot be nil') if filter.nil?
    return errors.add(:filter, 'must be a hash') unless filter.is_a?(Hash)

    outer_keys = [:filter, :projection, :paging, :sorting]

    if filter.keys.map(&:to_sym).intersect?(outer_keys)
      keys = outer_keys.join(', ')
      return errors.add(:filter, "must be an inner filter, cannot contain any of #{keys}")
    end

    # Check the filter is valid without executing the actual query
    begin
      build_generator.filter_as_relation.to_sql
    rescue StandardError => e
      errors.add(:filter, e.message.to_s)
    end
  end
end
