class AnalysisJob < ActiveRecord::Base

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_analysis_jobs
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_analysis_jobs
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_analysis_jobs

  belongs_to :script, inverse_of: :analysis_jobs
  belongs_to :saved_search, inverse_of: :analysis_jobs
  has_many :projects, through: :saved_search

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :script, existence: true
  validates :saved_search, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }, uniqueness: { case_sensitive: false }
  validates :script_settings, presence: true

  #validates :process_new, :inclusion => { :in => [true, false] }, allow_nil: true
  #validate :data_set_cannot_process_new

  #serialize :script_settings, Hash

  private

  # custom validation methods
  #def data_set_cannot_process_new
  #  return if process_new.nil?
  #
  #  errors.add(:level, 'An analysis job that references a data set cannot process new recordings.') if self.data_set_identifier && self.process_new
  #end
  #
end
