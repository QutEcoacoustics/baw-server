class AudioEvent < ActiveRecord::Base

  attr_accessible :audio_recording_id, :start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference,
                  :tags_attributes, :tag_ids

  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  has_many :taggings # no inverse of specified, as it interferes with through: association
  has_many :tags, through: :taggings

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_events
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_events
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_events
  has_many :audio_event_comments, inverse_of: :audio_event

  accepts_nested_attributes_for :tags

  # add created_at and updated_at stamper
  stampable

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # validation
  validates :audio_recording_id, presence: true
  validates :is_reference, inclusion: {in: [true, false]}
  validates :start_time_seconds, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :end_time_seconds, numericality: {greater_than_or_equal_to: 0}, allow_nil: true
  validates :low_frequency_hertz, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :high_frequency_hertz, numericality: {greater_than_or_equal_to: 0}, allow_nil: true

  validate :start_must_be_lte_end
  validate :low_must_be_lte_high

  before_validation :set_tags, on: :create

  # Scopes
  scope :start_after, lambda { |offset_seconds| where('start_time_seconds > ?', offset_seconds) }
  scope :start_before, lambda { |offset_seconds| where('start_time_seconds < ?', offset_seconds) }
  scope :end_after, lambda { |offset_seconds| where('end_time_seconds > ?', offset_seconds) }
  scope :end_before, lambda { |offset_seconds| where('end_time_seconds < ?', offset_seconds) }

  # postgres-specific
  scope :select_start_absolute, lambda { select('audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval) as start_time_absolute') }
  scope :select_end_absolute, lambda { select('audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval) as end_time_absolute') }
  scope :check_permissions, lambda { |user|
    if user.is_admin?
      where('1 = 1') # don't change query
    else
      creator_id_check = 'projects.creator_id = ?'
      permissions_check = '(permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\'))'
      where("#{creator_id_check} OR #{permissions_check}", user.id, user.id)
    end
  }

  # @param [User] user
  # @param [Hash] params
  def self.filtered(user, params)
    # get a paged collection of all audio_events the current user can access
    ### option params ###
    # reference: [true, false] (optional)
    # tagsPartial: comma separated text (optional)
    # freqMin: double (optional)
    # freqMax: double (optional)
    # annotationDuration: double (optional)
    # page: int (optional)
    # items: int (optional)
    # userId: int (optional)
    # audioRecordingId: int (optional)

    #.joins(:tags, :owner, audio_recording: {site: {projects: :permissions}})

    # eager load tags and projects
    query = AudioEvent
    .includes([:creator, :tags, audio_recording: {site: {projects: :permissions}}])
    .check_permissions(user)

    query = AudioEvent.filter_reference(query, params)
    query = AudioEvent.filter_tags(query, params)
    query = AudioEvent.filter_distance(query, params)
    query = AudioEvent.filter_user(query, params)
    query = AudioEvent.filter_audio_recording(query, params)
    query = AudioEvent.filter_paging(query, params)

    query = query.select('audio_events.*, audio_recording.recorded_date, sites.name, sites.id, user.user_name, user.id')
    Rails.logger.info "AudioEvent filtered: #{query.to_sql}"
    query
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_tags(query, params)
    if params.include?(:tagsPartial) && !params[:tagsPartial].blank?
      tags_partial = CSV.parse(params[:tagsPartial], col_sep: ',').flatten.map { |item| item.trim(' ', '') }.join('|').downcase
      tags_query = AudioEvent.joins(:tags).where('lower(tags.text) SIMILAR TO ?', "%(#{tags_partial})%").select('audio_events.id')
      query.where(id: tags_query)
    else
      query
    end
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_reference(query, params)
    if params.include?(:reference) && params[:reference] == 'true'
      query.where(is_reference: true)
    elsif params.include?(:reference) && params[:reference] == 'false'
      query.where(is_reference: false)
    else
      query
    end
  end

  # @param [Hash] params
  # @param [Symbol] params_symbol
  # @param [Integer] min
  # @param [Integer] max
  def self.filter_count(params, params_symbol, default = 1, min = 1, max = nil)
    value = default
    if params.include?(params_symbol)
      value = params[params_symbol].to_i
    end

    if value < min
      value = min
    end

    if !max.blank? && value > max
      value = max
    end

    value
  end

  # Postgres-specific queries
  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_distance(query, params)
    if params.include?(:freqMin) || params.include?(:freqMax) || params.include?(:annotationDuration)
      compare_items = []
      compare_text = []

      if params.include?(:freqMin)
        compare_items.push(params[:freqMin].to_f)
        compare_text.push('power(audio_events.low_frequency_hertz - ?, 2)')
      end

      if params.include?(:freqMax)
        compare_items.push(params[:freqMax].to_f)
        compare_text.push('power(audio_events.high_frequency_hertz - ?, 2)')
      end

      if params.include?(:annotationDuration)
        compare_items.push(params[:annotationDuration].to_f)
        compare_text.push('power((audio_events.end_time_seconds - audio_events.start_time_seconds) - ?, 2)')
      end

      dangerous_sql = 'sqrt('+compare_text.join(' + ')+')'
      sanitized_sql = sanitize_sql([dangerous_sql, compare_items].flatten, self.table_name)
      query.select(sanitized_sql + ' as distance_calc').order(sanitized_sql)
    else
      query.order('audio_events.created_at DESC')
    end
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_paging(query, params)

    defaults = AudioEvent.filter_paging_defaults

    page = defaults[:page]
    if params.include?(:page)
      page = params[:page].to_i
    end

    items = defaults[:items]
    if params.include?(:items)
      items = params[:items].to_i
    end

    query.offset((page - 1) * items).limit(items)
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_user(query, params)
    if params.include?(:userId)
      creator_id_check = 'audio_events.creator_id = ?'
      updater_id_check = 'audio_events.updater_id = ?'
      user_id = params[:userId].to_i
      query.where("(#{creator_id_check} OR #{updater_id_check})", user_id, user_id)
    else
      query
    end
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_audio_recording(query, params)
    if params.include?(:audioRecordingId)
      audio_recording_id = params[:audioRecordingId].to_i
      query.where(audio_recording_id: audio_recording_id)
    else
      query
    end
  end

  def self.filter_paging_defaults
    {
        page: 1,
        items: 20
    }
  end

  private

  # custom validation methods
  def start_must_be_lte_end
    return unless end_time_seconds && start_time_seconds

    if start_time_seconds > end_time_seconds then
      errors.add(:start_time_seconds, 'must be lower than end time')
    end
  end

  def low_must_be_lte_high
    return unless high_frequency_hertz && low_frequency_hertz

    if low_frequency_hertz > high_frequency_hertz then
      errors.add(:start_time_seconds, 'must be lower than high frequency')
    end
  end

  def set_tags
    existing_tags = []
    new_tags = []

    tags.each do |tag|
      existing_tag = Tag.find_by_text(tag.text)
      if existing_tag
        existing_tags.push(existing_tag)
      else
        new_tags.push(tag)
      end
    end

    self.tags = new_tags + existing_tags
  end
end