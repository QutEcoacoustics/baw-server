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
#  project_id                                             :bigint
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
  belongs_to :project, optional: true

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

  enum :status, STATUS_ENUM, prefix: :status, validate: true

  include StateMachine

  EXPORT_TYPE_CAMTRAP_DP = 'camtrap_dp'

  EXPORT_TYPE_ENUM = {
    EXPORT_TYPE_CAMTRAP_DP => EXPORT_TYPE_CAMTRAP_DP
  }.freeze

  enum :export_type, EXPORT_TYPE_ENUM, prefix: :export_type, validate: true

  OPTIONS_CAMTRAP_DP = [
    :contributors,
    :project_capture_method,
    :project_sampling_design,
    :emit_project_license,
    :forced_timezone
  ].freeze

  # Add additional accessors for other export types, prefixed, as needed.
  # Usage: export.camtrap_dp_contributors, etc.
  store_accessor :options, *OPTIONS_CAMTRAP_DP, prefix: :camtrap_dp

  validate :validate_options_camtrap_dp, if: :export_type_camtrap_dp?
  validate :attachment_acceptable, if: -> { file.attached? }
  validate :validate_obfuscate_locations, if: -> { obfuscate_locations == false }

  validates :name, length: { minimum: 2, maximum: 255 }
  validates :export_type, presence: true
  validates :filter, presence: true
  validates :started_at, :finished_at,
    allow_blank: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }

  # Raised by a generator for permanent, safe-to-show errors.
  class UserFacingError < StandardError; end

  # Run the generator for the export, handling file attachment and state transitions.
  #
  # @param resume [Boolean] when true, also generate an export whose status is already `working` (used on job retries).
  #   When false (default), an export that is already `working` is skipped.
  # @raise [UserFacingError] if a permanent, safe-to-show error occurs during generation.
  # @return [void]
  def generate(resume: false)
    return unless claim_for_generation!(resume:)

    build_generator.call do |io, filename, content_type|
      file.attach(io:, filename:, content_type:)
    end

    ready!
  rescue UserFacingError => e
    record_failure!(e.message)
  rescue StandardError
    # For any unexpected errors, record a generic message, then re-raise.
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

      file&.purge
      update!(purged: true)
    end
  end

  private

  # Claims the export for generation.
  #
  # @param resume [Boolean] when true, a `working` export can be claimed for generation (used when a job retries).
  # @raise [UserFacingError] if the project is missing.
  # @return [Boolean] true if the export is claimed for generation, false if it is not.
  def claim_for_generation!(resume:)
    with_lock do
      next false if status_ready? || (status_working? && !resume)

      # An export row may exist without a project, but it cannot be generated without one.
      raise UserFacingError, 'project must be present' if project.blank?

      working!(resume:)
      true
    end
  end

  # Each export type has a generator implementing the interface documented on CamtrapDpGenerator.
  def build_generator
    case export_type
    when EXPORT_TYPE_CAMTRAP_DP then CamtrapDpGenerator.new(self)
    else raise "Unsupported export type: #{export_type}"
    end
  end

  # Validates the options for a Camtrap DP export.
  # @return [void] Adds errors to the export if the options are invalid.
  def validate_options_camtrap_dp
    result = CamtrapDpOptionsContract.new.call(options || {})
    return if result.success?

    result.errors.each do |error|
      errors.add(:options, "#{error.path.join('.')} #{error.text}")
    end
  end

  # Validates the attached file.
  # @return [void] Adds an error if the attached file is not a zip file.
  def attachment_acceptable
    return if file.content_type == 'application/zip'

    errors.add(:file, 'must be a zip file')
  end

  # Validates the obfuscate_locations setting.
  #
  # @return [void] Adds an error if the creator is not the project owner and
  # tries to set obfuscate_locations to false.
  def validate_obfuscate_locations
    return if project.present? && creator_is_owner?

    errors.add(:obfuscate_locations, 'can only be set to false by the project owner')
  end

  def creator_is_owner?
    Access::Core.can_any?(creator, Access::Permission::OWNER, project)
  end
end
