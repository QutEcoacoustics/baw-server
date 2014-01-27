class Job < ActiveRecord::Base
  attr_accessible :script_id, :dataset_id, :deleted_at, :deleter_id, :annotation_name,
                  :name, :description, :script_settings, :creator_id, :updater_id

  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :script, inverse_of: :jobs
  belongs_to :dataset, inverse_of: :jobs
  has_one :project, through: :dataset  # using has_one instead of belongs_to to use :through

  # userstamp
  stampable

  # validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }, uniqueness: { case_sensitive: false }

  validates :name, :presence => true
  validates :script_settings, :presence => true
  validates :dataset_id, :presence => true
  validates :script_id, :presence => true

  #validates :process_new, :inclusion => { :in => [true, false] }, allow_nil: true
  #validate :data_set_cannot_process_new

  private

  # custom validation methods
  #def data_set_cannot_process_new
  #  return if process_new.nil?
  #
  #  errors.add(:level, 'An analysis job that references a data set cannot process new recordings.') if self.data_set_identifier && self.process_new
  #end
  #
end
