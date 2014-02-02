class Script < ActiveRecord::Base
  attr_accessible :analysis_identifier, :data_file, :description, :name, :notes, :settings_file, :verified, :version, :creator_id


  has_attached_file :settings_file
  has_attached_file :data_file

  # relationships
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :updated_by, class_name: 'Script', foreign_key: :updated_by_script_id
  has_one    :update_from, class_name: 'Script', foreign_key: :updated_by_script_id
  has_one    :latest_update, class_name: 'Script', foreign_key: :original_script_id, order: 'created_at DESC'
  has_many   :jobs, inverse_of: :script

  # userstamp
  stampable

  #validation
  validates :name, presence: true
  validates :analysis_identifier, presence: true
  validates :settings_file, attachment_presence: true
  validate :version, :version_increase, on: :create
  validates_attachment_content_type :settings_file, content_type: 'text/plain'

  # scopes
  scope :latest_versions, -> { where(updated_by_script_id: nil) }

  def latest_version
    if self.is_latest_version?
      self
    else
      self.updated_by.latest_version
    end
  end

  def is_latest_version?
    self.updated_by.blank?
  end

  def display_name
    "#{self.name} - v. #{self.version}"
  end

  def version_increase
    unless update_from.blank?
      unless version > update_from.version
        errors.add(:version, "must't be higher then previous version #{update_from.version}")
      end
    end
  end
end
