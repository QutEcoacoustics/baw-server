class Dataset < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  attr_accessible :description, :end_date, :end_time, :filters, :name, :number_of_samples, :number_of_tags,
                  :start_date, :start_time, :types_of_tags, :site_ids,
                  :has_time, :has_date

  attr_accessor   :has_time, :has_date # custom fields to set dates and times to nil if not selected in form

  belongs_to :user, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :project, inverse_of: :datasets
  has_and_belongs_to_many :sites, uniq: true
  has_many   :jobs, inverse_of: :dataset


  AVAILABLE_FILTERS = [:wind, :rain]
  enumerize :filters, in: AVAILABLE_FILTERS, predicates: true # , multiple: true (does not work in the form when editing values)
  AVAILABLE_TAG_TYPES = [:human, :computer]
  enumerize :types_of_tags, in: AVAILABLE_TAG_TYPES, predicates: true

  # userstamp
  stampable

  # validation
  validates :name, presence: true, uniqueness: { case_sensitive: false, scope: :creator_id, message: 'should be unique per user' }
  validates_presence_of :start_time, if: :end_time?
  validates_presence_of :end_time, if: :start_time?
  validates_presence_of :start_date, if: :end_date?
  validates_presence_of :end_date, if: :start_date?

  validates :start_date, allow_nil: true, allow_blank: true, timeliness: {type: :datetime}
  validates :end_date, allow_nil: true, allow_blank: true, timeliness: {type: :datetime}

  validate :date_start_before_end

  validates :start_time, allow_nil: true, allow_blank: true, timeliness: {type: :time}
  validates :start_time, allow_nil: true, allow_blank: true, timeliness: {type: :time}

  validate :time_start_before_end

  def has_time
    !self.start_time.blank?
  end

  def has_date
    !self.start_date.blank?
  end

  def execute_query
    AudioRecording.scoped
  end

  private

  def date_start_before_end
    if !self.start_date.blank? && !self.end_date.blank? && self.start_date >= self.end_date
      self.errors.add(:start_date, "must be before end date")
    end
  end

  def time_start_before_end
    if !self.start_time.blank? && !self.end_time.blank? && self.start_time >= self.end_time
      self.errors.add(:start_time, "must be before end time")
    end
  end

end
