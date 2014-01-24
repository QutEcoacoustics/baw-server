class Dataset < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  attr_accessible :processing_status, :total_duration_seconds,
                  :audio_recording_count,
                  :earliest_datetime, :earliest_time_of_day,
                  :latest_datetime, :latest_time_of_day

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
  validates :audio_recording_count, presence: false, numericality: { only_integer: true }
  validates :earliest_datestime, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :datetime}
  validates :earliest_time_of_day, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :time}
  validates :latest_datestime, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :datetime}
  validates :latest_time_of_day, presence: false, timeliness: {on_or_before: lambda { Date.current }, type: :time}

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
end
