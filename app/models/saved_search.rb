class SavedSearch < ActiveRecord::Base
  extend Enumerize
  extend ActiveModel::Naming

  attr_accessible :description, :end_date, :end_time, :filters, :name, :number_of_samples, :number_of_tags,
                  :start_date, :start_time, :types_of_tags, :site_ids, :tag_text_filters, :auto_generated_identifer,
                  :tag_text_filters_list,
                  :has_time, :has_date

  # custom fields to set dates and times to nil if not selected in form
  attr_accessor :has_time, :has_date, :selected_types_of_tags

  belongs_to :user, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id
  belongs_to :project, inverse_of: :saved_searches
  has_many :datasets, inverse_of: :saved_search
  has_and_belongs_to_many :sites, uniq: true

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

  # userstamp
  stampable
  acts_as_paranoid({column: 'deleted_at', column_type: 'time'})

  # validation
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


  # take in the ActiveRecord AudioRecording (with all attributes) and the dataset model that specifies the metadata.
  # use the saved_search attributes to create the { :audiorecording_id, :start_offset, :end_offset } list
  # results = execute AudioRecording.readonly, self

  @date_format_string = '%Y-%m-%d'
  @time_format_string = '%H:%M:%S'
  @date_and_time_format_string = @date_format_string+'T'+@time_format_string

  def preview_results(audio_recordings)
    audio_recordings_query = query_site_ids(audio_recordings)
    audio_recordings_query = query_dates(audio_recordings_query)
    audio_recordings_query = query_number_of_tags(audio_recordings_query)
    audio_recordings_query = query_types_of_tags(audio_recordings_query)
    audio_recordings_query = query_tag_filters(audio_recordings_query)

    #tz = Time.zone.formatted_offset

    audio_recordings_query.select(%{
count(*) as audio_recording_count,
sum(duration_seconds) as total_duration_seconds,
min(recorded_date AT TIME ZONE 'UTC') as earliest_datetime,
min(CAST(CAST(recorded_date AT TIME ZONE 'UTC' as time) as interval)) as earliest_time_of_day,
max((recorded_date + CAST(duration_seconds || ' seconds' as interval)) AT TIME ZONE 'UTC') as latest_datetime,
LEAST(max(CAST(CAST(recorded_date AT TIME ZONE 'UTC' as time) as interval) + CAST(duration_seconds || ' seconds' as interval)), '23:59:59'::interval) as latest_time_of_day
                                  })
  end

=begin
total_duration_seconds,
                  :audio_recording_count,
                  :earliest_datetime, :earliest_time_of_day,
                  :latest_datetime, :latest_time_of_day

# http://stackoverflow.com/questions/5149397/activerecord-calculating-multiple-averages
SpellingScore.select("AVG(`spelling_scores`.`score`) AS average_score,
AVG(`spelling_scores`.`time`) AS average_time, COUNT(*) AS question_count, user_id AS
user_id").where(:user_id => users).group(:user_id).includes(:user).order('users.last')


results = MyObject.select('name, count(*) as how_many')
                  .group(:name)
                  .order(:how_many)
# And later...
results.each do |o|
    puts "#{o.name} has #{o.how_many}"
end

select
min(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00'),
max(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval)),
max(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as date)),
min(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as date)),
max(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as time)),
min(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as time)),
count(*),
sum(duration_seconds)
FROM audio_recordings ar
WHERE recorded_date >= '2012-11-10' AND recorded_date < '2012-11-16'
;

-- select tags.text, count(*)
-- from audio_events
-- inner join audio_recordings on audio_events.audio_recording_id = audio_recordings.id
-- inner join audio_events_tags on audio_events.id = audio_events_tags.audio_event_id
-- inner join tags on audio_events_tags.tag_id = tags.id
-- WHERE recorded_date >= '2012-01-01' AND recorded_date < '2012-11-15'
-- group by tags.text
-- order by count(*) DESC;

SELECT
recorded_date,
recorded_date AT TIME ZONE 'UTC' ,
recorded_date AT TIME ZONE INTERVAL '+10:00',
recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00',

recorded_date + CAST(duration_seconds || ' seconds' as interval),
CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as time),
CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as time),
recorded_date - date_trunc('day', recorded_date)

FROM audio_recordings ar
WHERE recorded_date >= '2012-11-10' AND recorded_date < '2012-11-16'
order by recorded_date;
=end

  def execute(audio_recordings)

    # - dataset (collection of audio recordings)
    # -- audio recording (a single audio file)
    # --- segment (start and end offset within an audio recording)
    # ---- sub-segment (start and end offset within a segment)

    audio_recordings_query = query_site_ids(audio_recordings)
    audio_recordings_query = query_dates(audio_recordings_query)
    audio_recordings_query = query_number_of_tags(audio_recordings_query)
    audio_recordings_query = query_types_of_tags(audio_recordings_query)
    audio_recordings_query = query_tag_filters(audio_recordings_query)

    # times - start and end - creates segments
    # filters - e.g. wind, rain, other indicies - removes audio from result set
    # number of samples - select a random number of sub-segments
    #puts recordings.explain
    audio_recordings_query.select([:id, :uuid, :duration_seconds, :recorded_date])
  end


  def query_site_ids(audio_recordings)
    unless self.site_ids.blank?
      audio_recordings = audio_recordings.where(site_id: self.site_ids)
    end

    audio_recordings
  end

  def query_dates(audio_recordings)
    unless self.start_date.blank?
      date_string = self.start_date.to_time.strftime(@date_format_string)
      audio_recordings = audio_recordings.end_after date_string
    end

    unless self.end_date.blank?
      date_string = self.end_date.to_time.strftime(@date_format_string)
      audio_recordings = audio_recordings.start_before date_string
    end

    audio_recordings
  end

  def query_types_of_tags(audio_recordings)
    unless self.types_of_tags.blank?
      audio_recordings = audio_recordings.tag_types self.types_of_tags.to_a
    end

    audio_recordings
  end

  def query_number_of_tags(audio_recordings)
    unless self.number_of_tags.blank?
      audio_recordings = audio_recordings.tag_count self.number_of_tags
    end

    audio_recordings
  end

  def query_tag_filters(audio_recordings)
    unless self.tag_text_filters.blank?
      self.tag_text_filters.each do |tag_text|
        audio_recordings = audio_recordings.tag_text tag_text
      end
    end

    audio_recordings
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

end
