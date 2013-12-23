class Dataset < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  attr_accessible :description, :end_date, :end_time, :filters, :name, :number_of_samples, :number_of_tags,
                  :start_date, :start_time, :types_of_tags, :site_ids,
                  :has_time, :has_date

  # custom fields to set dates and times to nil if not selected in form
  attr_accessor :has_time, :has_date, :selected_types_of_tags

  belongs_to :user, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :project, inverse_of: :datasets
  has_and_belongs_to_many :sites, uniq: true
  has_many :jobs, inverse_of: :dataset

  before_save :generate_dataset_result

  has_attached_file :dataset_result,
                    path: ':rails_root/public/system/:class/:attachment/:id_partition/:style/:filename',
                    url: '/system/:class/:attachment/:id_partition/:style/:filename'

  AVAILABLE_NUMBER_OF_TAGS = {'None' => 0, 'At least one' => 1}

  #AVAILABLE_FILTERS = [:wind, :rain]
  #enumerize :filters, in: AVAILABLE_FILTERS, predicates: true # , multiple: true (does not work in the form when editing values)
  #AVAILABLE_TAG_TYPES = [:human, :computer]
  #enumerize :types_of_tags, in: AVAILABLE_TAG_TYPES, predicates: true

  # the magic solution to saving multiple selection
  # see https://github.com/brainspec/enumerize/blob/master/test/activerecord_test.rb#L50
  serialize :types_of_tags, Array
  enumerize :types_of_tags, in: Tag::AVAILABLE_TYPE_OF_TAGS, predicates: true, multiple: true

  # userstamp
  stampable

  # validation
  validates :name, presence: true, uniqueness: {case_sensitive: false, scope: :creator_id, message: 'should be unique per user'}
  validates_presence_of :start_time, if: :end_time?
  validates_presence_of :end_time, if: :start_time?
  validates_presence_of :start_date, if: :end_date?
  validates_presence_of :end_date, if: :start_date?
  validates :number_of_tags, inclusion: {in: [0, 1]}, allow_nil: true, allow_blank: true

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

  def selected_types_of_tags
    Tag::AVAILABLE_TYPE_OF_TAGS_DISPLAY.select { |item| self.types_of_tags.to_a.include? item[:id].to_s }.collect { |item| item[:name] }.join(', ')
  end

  def selected_number_of_tags
    AVAILABLE_NUMBER_OF_TAGS.select{ |key, value| self.number_of_tags == value }.keys.first
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

  def generate_dataset_result
    result = execute AudioRecording.readonly, self

    # http://stackoverflow.com/questions/5166782/write-stream-to-paperclip/5188448#5188448
    self.dataset_result = StringIO.new(result.to_json)

    self.dataset_result_content_type = 'application/json'
    self.dataset_result_file_name = "dataset_result.json"

    #self.save!

  end

  # take in the ActiveRecord AudioRecording (with all attributes) and the dataset model that specifies the metadata.
  # use the saved_search attributes to create the { :audiorecording_id, :start_offset, :end_offset } list
  def execute(audio_recording, dataset_metadata)

    date_format_string = '%Y-%m-%d'
    time_format_string = '%H:%M:%S'
    date_and_time_format_string = date_format_string+'T'+time_format_string

    recordings = audio_recording.scoped

    # sites
    unless dataset_metadata.site_ids.blank?
      recordings = recordings.where(site_id: dataset_metadata.site_ids)
    end

    # dates - exclude audio outside the start and end dates if they are specified
    unless dataset_metadata.start_date.blank?
      date_string = dataset_metadata.start_date.to_time.strftime(date_format_string)
      recordings = recordings.end_after date_string
    end

    unless dataset_metadata.end_date.blank?
      date_string = dataset_metadata.end_date.to_time.strftime(date_format_string)
      recordings = recordings.start_before date_string
    end

    # times - creates segments

    # number of tags
    unless dataset_metadata.number_of_tags.blank?
      recordings = recordings.tag_count dataset_metadata.number_of_tags
    end

    # types of tags
    #unless dataset_metadata.

    #recordings.explain
    recordings
  end
end
