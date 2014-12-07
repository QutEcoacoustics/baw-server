class Dataset < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  attr_accessible :description, :end_date, :end_time, :filters, :name, :number_of_samples, :number_of_tags,
                  :start_date, :start_time, :types_of_tags, :site_ids, :tag_text_filters, :tag_text_filters_list,
                  :has_time, :has_date

  # custom fields to set dates and times to nil if not selected in form
  attr_accessor :has_time, :has_date, :selected_types_of_tags, :json_dataset_result_info

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_datasets
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_datasets
  belongs_to :project, inverse_of: :datasets
  has_and_belongs_to_many :sites, uniq: true
  has_many :jobs, inverse_of: :dataset

  #before_save :generate_dataset_result

  has_attached_file :dataset_result

  AVAILABLE_NUMBER_OF_TAGS = {'None' => 0, 'At least one' => 1}

  #AVAILABLE_FILTERS = [:wind, :rain]
  #enumerize :filters, in: AVAILABLE_FILTERS, predicates: true # , multiple: true (does not work in the form when editing values)
  #AVAILABLE_TAG_TYPES = [:human, :computer]
  #enumerize :types_of_tags, in: AVAILABLE_TAG_TYPES, predicates: true

  # the magic solution to saving multiple selection
  # see https://github.com/brainspec/enumerize/blob/master/test/activerecord_test.rb#L50
  serialize :types_of_tags, Array
  enumerize :types_of_tags, in: Tag::AVAILABLE_TYPE_OF_TAGS, predicates: true, multiple: true

  # search by tag text (array of partial tag text)
  serialize :tag_text_filters, Array

  # association validations
  validates :project, existence: true
  validates :creator, existence: true

  # attribute validations
  validates :name, presence: true, uniqueness: {case_sensitive: false, scope: :creator_id, message: 'should be unique per user'}
  validates_presence_of :start_time, if: :end_time?
  validates_presence_of :end_time, if: :start_time?
  validates_presence_of :start_date, if: :end_date?
  validates_presence_of :end_date, if: :start_date?
  validates :number_of_tags, inclusion: {in: [0, 1]}, allow_nil: true, allow_blank: true

  validate :tag_text_filters_validation

  validates :start_date, allow_nil: true, allow_blank: true, timeliness: {type: :datetime}
  validates :end_date, allow_nil: true, allow_blank: true, timeliness: {type: :datetime}

  validate :date_start_before_end

  validates :start_time, allow_nil: true, allow_blank: true, timeliness: {type: :time}
  validates :start_time, allow_nil: true, allow_blank: true, timeliness: {type: :time}

  validate :time_start_equal_end

  validate :tag_count_and_tag_text_filters

  def has_time
    !self.start_time.blank?
  end

  def has_date
    !self.start_date.blank?
  end

  def has_time=(new_value)
    if new_value == '0'
      self.start_time = nil
      self.end_time = nil
    end
  end

  def has_date=(new_value)
    if new_value == '0'
      self.start_date = nil
      self.end_date = nil
    end
  end

  def selected_types_of_tags
    Tag::AVAILABLE_TYPE_OF_TAGS_DISPLAY.select { |item| self.types_of_tags.to_a.include? item[:id].to_s }.collect { |item| item[:name] }.join(', ')
  end

  def selected_number_of_tags
    AVAILABLE_NUMBER_OF_TAGS.select { |key, value| self.number_of_tags == value }.keys.first
  end

  def tag_text_filters_list
    self.tag_text_filters.join(', ')
  end

  def tag_text_filters_list=(new_value)
    tag_names = new_value.split(/,\s+/)
    self.tag_text_filters = tag_names
  end

  def dataset_result_info
    if json_dataset_result_info.blank?
      if self.dataset_result.file? && File.exists?(self.dataset_result.path)
        json_dataset_result_info = JSON.parse File.read(self.dataset_result.path)
      end
    end

    json_dataset_result_info
  end

  private

  def date_start_before_end
    if !self.start_date.blank? && !self.end_date.blank? && self.start_date > self.end_date
      self.errors.add(:start_date, "must be before end date")
    end
  end

  def time_start_equal_end
    if !self.start_time.blank? && !self.end_time.blank? && self.start_time == self.end_time
      self.errors.add(:start_time, "must not be equal to end time")
    end
  end

  def tag_text_filters_validation
    # must be an array if given, but can be empty or not given
    unless self.tag_text_filters.is_a?(Array)
      self.errors.add(:tag_text_filters, 'must be an array')
    end
  end

  def tag_count_and_tag_text_filters
    if self.number_of_tags == 0 && self.tag_text_filters.size > 0
      self.errors.add(:number_of_tags, 'must be \'No restriction\' or \'At least one\' if tags are given')
    end
  end

  def generate_dataset_result
    results = execute AudioRecording.readonly, self

    total_duration = results.reduce(0) { |sum, value|
      sum + value.duration_seconds
    }

    earliest = results.reduce { |current, value|
      if current.blank?
        value
      else
        current.recorded_date < value.recorded_date ? current : value
      end
    }

    most_recent = results.reduce { |current, value|
      if current.blank?
        value
      else
        current.recorded_date > value.recorded_date ? current : value
      end
    }

    stored_info = {
        total_duration_seconds: total_duration,
        begin: earliest,
        end: most_recent,

        results: results
    }

    ## http://stackoverflow.com/questions/5166782/write-stream-to-paperclip/5188448#5188448
    #self.dataset_result = StringIO.new(stored_info.to_json)

    #self.dataset_result_content_type = 'application/json'
    #self.dataset_result_file_name = "dataset_result.json"

    #self.save!

  end

  # take in the ActiveRecord AudioRecording (with all attributes) and the dataset model that specifies the metadata.
  # use the saved_search attributes to create the { :audiorecording_id, :start_offset, :end_offset } list
  def execute(audio_recording, dataset_metadata)

    # - dataset (collection of audio recordings)
    # -- audio recording (a single audio file)
    # --- segment (start and end offset within an audio recording)
    # ---- sub-segment (start and end offset within a segment)

    date_format_string = '%Y-%m-%d'
    time_format_string = '%H:%M:%S'
    date_and_time_format_string = date_format_string+'T'+time_format_string

    recordings = audio_recording.all

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

    # times - start and end - creates segments
    # filters - e.g. wind, rain, other indicies - removes audio from result set
    # number of samples - select a random number of sub-segments

    # number of tags
    unless dataset_metadata.number_of_tags.blank?
      recordings = recordings.tag_count dataset_metadata.number_of_tags
    end

    # types of tags
    unless dataset_metadata.types_of_tags.blank?
      recordings = recordings.tag_types dataset_metadata.types_of_tags.to_a
    end

    unless dataset_metadata.tag_text_filters.blank?
      dataset_metadata.tag_text_filters.each do |tag_text|
        recordings = recordings.tag_text tag_text
      end
    end

    #puts recordings.explain
    recordings.select(:id, :uuid, :duration_seconds, :recorded_date)
  end
end
