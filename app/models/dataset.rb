class Dataset < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  attr_accessible :processing_status, :total_duration_seconds,
                  :earliest_datetime, :earliest_date, :earliest_time,
                  :latest_datetime, :latest_date, :latest_time

  belongs_to :user, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :saved_search, inverse_of: :datasets
  has_many :jobs, inverse_of: :dataset

  # userstamp
  stampable
  acts_as_paranoid({column: 'deleted_at', column_type: 'time'})

  # enums
  PROCESSING_STATUS_SYMBOLS = [:new, :generating, :ready, :unknown]
  PROCESSING_STATUS = PROCESSING_STATUS_SYMBOLS.map { |item| item.to_s }

  PROCESSING_STATUS_DISPLAY = [
      {id: :new, name: 'New'},
      {id: :generating, name: 'Generating'},
      {id: :ready, name: 'Ready'},
      {id: :unknown, name: 'Unknown'}
  ]

  enumerize :processing_status, in: PROCESSING_STATUS, predicates: true, multiple: false

  # validation
  validates :processing_status, presence: true
  validates :total_duration_seconds, presence: false, numericality: true
  validates :earliest_datestamp, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :datetime}
  validates :earliest_date, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :date}
  validates :earliest_time, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :time}
  validates :latest_datestamp, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :datetime}
  validates :latest_date, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :date}
  validates :latest_time, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :time}

  private

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

    # http://stackoverflow.com/questions/5166782/write-stream-to-paperclip/5188448#5188448
    self.dataset_result = StringIO.new(stored_info.to_json)

    self.dataset_result_content_type = 'application/json'
    self.dataset_result_file_name = "dataset_result.json"

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
    recordings.select([:id, :uuid, :duration_seconds, :recorded_date])
  end
end
