# frozen_string_literal: true

# when HarvestItem is used in the context of a job, it does not have access to
# rails' normal autoloader... for some reason?
require(BawApp.root / 'app/serializers/hash_serializer')

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  harvest_id         :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_path    (path)
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (harvest_id => harvests.id)
#  fk_rails_...  (uploader_id => users.id)
#
class HarvestItem < ApplicationRecord
  extend Enumerize
  # optional audio recording - when a harvested audio file is complete, it will match a recording
  belongs_to :audio_recording, optional: true

  # harvests were introduced after harvest_items, hence the parent association is optional
  belongs_to :harvest, optional: true

  belongs_to :uploader, class_name: User.name, foreign_key: :uploader_id

  validates :path, presence: true, length: { minimum: 2 }

  STATUS_NEW = :new
  STATUS_METADATA_GATHERED = :metadata_gathered
  STATUS_FAILED = :failed
  STATUS_COMPLETED = :completed
  STATUS_ERRORED = :errored
  STATUSES = [STATUS_NEW, STATUS_METADATA_GATHERED, STATUS_FAILED, STATUS_COMPLETED, STATUS_ERRORED].freeze

  enumerize :status, in: STATUSES, default: :new

  serialize :info, ::HashSerializer

  def new?
    status == STATUS_NEW
  end

  def metadata_gathered?
    status == STATUS_METADATA_GATHERED
  end

  def failed?
    status == STATUS_FAILED
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def errored?
    status == STATUS_ERRORED
  end

  def terminal_status?
    completed? || failed? || errored?
  end
end
