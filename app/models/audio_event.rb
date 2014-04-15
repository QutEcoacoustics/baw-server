class AudioEvent < ActiveRecord::Base

  attr_accessible :audio_recording_id, :start_time_seconds, :end_time_seconds, :low_frequency_hertz, :high_frequency_hertz, :is_reference,
                  :tags_attributes, :tag_ids

  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  has_many :taggings # no inverse of specified, as it interferes with through: association
  has_many :tags, through: :taggings
  belongs_to :owner, class_name: 'User', foreign_key: :creator_id
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id


  accepts_nested_attributes_for :tags


  # userstamp
  stampable
  #acts_as_paranoid
  #validates_as_paranoid

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
      where # don't change query
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
    # option params:
    # page, items, reference, tags_partial

    query = AudioEvent
    .includes(:tags, :owner, audio_recording: {site: {projects: :permissions}})
    .select_start_absolute
    .select_end_absolute
    .check_permissions(user)

    query = AudioEvent.filter_reference(query, params)
    query = AudioEvent.filter_tags(query, params)
    query = AudioEvent.filter_distance(query, params)
    query = AudioEvent.filter_paging(query, params)

    puts "SQL: #{query.to_sql}"
    query
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_tags(query, params)
    if params.include?(:tagsPartial) && !params[:tagsPartial].blank?
      tags_partial = CSV.parse(params[:tagsPartial], col_sep: ',').flatten.map { |item| item.trim(' ', '') }.join('|').downcase
      tags_query = AudioEvent.joins(:tags).where('lower(tags.text) SIMILAR TO ?', "%(#{tags_partial})%").select('tags.id')
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

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_distance(query, params)
    if params.include?(:freqMin) || params.include?(:freqMax) || params.include?(:annotationDuration)
      compare_items = []
      compare_text = []

      if params.include?(:freqMin)
        compare_items << params[:freqMin].to_f
        compare_text << 'power(low_frequency_hertz - ?, 2)'
      end

      if params.include?(:freqMax)
        compare_items << params[:freqMax].to_f
        compare_text << 'power(high_frequency_hertz - ?, 2)'
      end

      if params.include?(:annotationDuration)
        compare_items << params[:annotationDuration].to_f
        compare_text << 'power((end_time_seconds - start_time_seconds) - ?, 2)'
      end

      dangerous_sql = 'sqrt('+compare_text.join(' + ')+')'
      sanitized_sql = sanitize_sql([dangerous_sql, compare_items].flatten, self.table_name)
      query.select(sanitized_sql).order(sanitized_sql)
    else
      query.order('audio_events.created_at DESC')
    end
  end

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
        existing_tags << existing_tag
      else
        new_tags << tag
      end
    end

    self.tags = new_tags + existing_tags
  end
end