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

  has_one_attached :archive

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
  }

  enum :status, STATUS_ENUM, prefix: :status, validate: true

  validate :attachment_acceptable, if: -> { archive.attached? }

  private

  def attachment_acceptable
    return if archive.content_type == 'application/zip'

    errors.add(:archive, 'must be a zip file')
  end
end
