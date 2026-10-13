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

  enum :status, STATUS_ENUM, prefix: :status, validate: true

  # We only have one export type currently.
  EXPORT_TYPE_CAMTRAP_DP = 'camtrap_dp'
  EXPORT_TYPE_ENUM = { EXPORT_TYPE_CAMTRAP_DP => EXPORT_TYPE_CAMTRAP_DP }.freeze

  enum :export_type, EXPORT_TYPE_ENUM, prefix: :export_type, validate: true

  #
  # Main generate method
  #
  def generate
    return if status_working?

    working!

    stored_options = options || {}

    BawWorkers::Export::CamtrapDp::Exporter::RequiredExporterOptions.new(
      user: creator,
      should_obfuscate: obfuscate_locations,
      package_title: name,
      contributors: stored_options['contributors'],
      project_capture_method: stored_options['project_capture_method'],
      project_sampling_design: stored_options['project_sampling_design'],
      emit_project_license: stored_options['emit_project_license'],
      forced_timezone: stored_options['forced_timezone']
    )
  rescue BawWorkers::Export::CamtrapDp::Errors::CamtrapDpError => e
    # Expected, permanent, user-facing failure. Record it and stop.
    record_failure!(e.message)
  rescue StandardError
    # Unexpected: record a generic message, then re-raise so the job framework
    # (retry_on / discard_on -> notify_error) handles retries and admin alerts.
    record_failure!('An unexpected error occurred while generating the export.')
    raise
  end

  def filter_as_relation
    raise 'project must be present' if project.blank?

    export_type_filter
  end

  def export_type_filter
    case export_type
    when EXPORT_TYPE_CAMTRAP_DP then camtrap_dp_filter_query
    else raise "Unsupported export type: #{export_type}"
    end
  end

  def camtrap_dp_filter_query
    Filter::Query.new(
      filter,
      Access::ByPermission.audio_events_tags(creator, project_ids: [project.id]),
      Tagging,
      Tagging.filter_settings
    ).query_without_paging_sorting
  end

  class InvalidTransition < StandardError; end

  validate :attachment_acceptable, if: -> { file.attached? }
  validate :validate_obfuscate_locations, if: -> { obfuscate_locations == false }
  validate :validate_camtrap_dp_options, if: :export_type_camtrap_dp?
  validates :filter, presence: true
  validates :started_at, :finished_at,
    allow_blank: true,
    timeliness: { on_or_before: -> { Time.zone.now }, type: :datetime }

  def purge!
    return if purged?

    file&.purge
    update!(purged: true)
  end

  private

  #
  # Validations
  #

  def validate_camtrap_dp_options
    result = CamtrapDpOptionsContract.new.call(options || {})
    return if result.success?

    result.errors.each do |error|
      errors.add(:options, "#{error.path.join('.')} #{error.text}")
    end
  end

  # Validates the attached file. Currently only allows zip files.
  def attachment_acceptable
    return if file.content_type == 'application/zip'

    errors.add(:file, 'must be a zip file')
  end

  # Only the project owner can set obfuscate_locations to false.
  #
  # @return [void] Adds an error if the creator is not the project owner and
  # tries to set obfuscate_locations to false.
  def validate_obfuscate_locations
    return if project.present? && creator_is_owner?

    errors.add(:obfuscate_locations, 'can only be set to false by the project owner')
  end

  #
  # State transition methods
  #

  def queued!
    validate_transition(from: [STATUS_PENDING], to: STATUS_QUEUED)

    update!(status: STATUS_QUEUED)
  end

  def working!
    # Allow re-entry so job retries (after a transient failure) can run again.
    validate_transition(from: [STATUS_PENDING, STATUS_QUEUED, STATUS_WORKING, STATUS_FAILED], to: STATUS_WORKING)

    update!(
      status: STATUS_WORKING,
      started_at: Time.current,
      error: nil,
      finished_at: nil
    )
  end

  def ready!
    validate_transition(from: [STATUS_WORKING], to: STATUS_READY)
    raise InvalidTransition, 'Cannot finish an export without a file' unless file.attached?

    update!(
      status: STATUS_READY,
      finished_at: Time.current,
      error: nil
    )
  end

  # Records a failed export. Uses update_columns to skip validations and
  # callbacks, and rescues any persistence error so the caller's original
  # exception is not replaced.
  def record_failure!(message)
    # rubocop:disable Rails/SkipsModelValidations -- skipping validations is the point
    update_columns(
      status: STATUS_FAILED,
      error: message,
      finished_at: Time.current,
      updated_at: Time.current
    )
    # rubocop:enable Rails/SkipsModelValidations
  rescue StandardError => e
    logger.error('Failed to record export failure', e)
  end

  #
  # Helper methods
  #
  def validate_transition(from:, to:)
    raise InvalidTransition, "Cannot transition from #{status} to #{to}" unless from.include?(status)
  end

  def creator_is_owner?
    Access::Core.can_any?(creator, Access::Permission::OWNER, project)
  end
end
