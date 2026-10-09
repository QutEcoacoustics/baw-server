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

  has_one_attached :archive

  # TODO: methods that manage the transitions. Shouldn't update the status manually anywhere.
  # E.g. methods like queued, working, finished with result, purged.
  # So can't manipulate the status and get an invalid state.
  # There is state machine here. Do it, or else lock down to 5 or 6 methods that manage the transitions.
  # Therefore easy to test.
  # E.g. enqueue, start etc. transitions from new to queued.
  # generate method does the working step and handle ready and failed.
  # purge method sets purged.
  # predicates inside each that guards against the transitions. e.g. can't do this if status is that. limit the method options.

  STATUS_PENDING = 'pending'
  STATUS_QUEUED  = 'queued'
  STATUS_WORKING = 'working'

  # Can only get to ready after working. Consistency could be called success.
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
