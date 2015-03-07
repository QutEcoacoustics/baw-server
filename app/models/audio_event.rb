class AudioEvent < ActiveRecord::Base
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  belongs_to :audio_recording, inverse_of: :audio_events
  has_many :taggings, inverse_of: :audio_event
  has_many :tags, through: :taggings

  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id', inverse_of: :created_audio_events
  belongs_to :updater, class_name: 'User', foreign_key: 'updater_id', inverse_of: :updated_audio_events
  belongs_to :deleter, class_name: 'User', foreign_key: 'deleter_id', inverse_of: :deleted_audio_events
  has_many :comments, class_name: 'AudioEventComment', foreign_key: 'audio_event_id', inverse_of: :audio_event

  accepts_nested_attributes_for :tags


  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates :audio_recording, existence: true
  validates :creator, existence: true

  # validation
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
                              permissions_check = 'permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\')'
                              reference_audio_event_check = 'audio_events.is_reference IS TRUE'
                              where("((#{creator_id_check}) OR (#{permissions_check}) OR (#{reference_audio_event_check}))", user.id, user.id)
                            end
                          }

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [:id, :audio_recording_id,
                       :start_time_seconds, :end_time_seconds,
                       :low_frequency_hertz, :high_frequency_hertz,
                       :is_reference,
                       :created_at, :creator_id, :updated_at],
        render_fields: [:id, :audio_recording_id,
                        :start_time_seconds, :end_time_seconds,
                        :low_frequency_hertz, :high_frequency_hertz,
                        :is_reference,
                        :creator_id, :updated_at, :created_at],
        text_fields: [],
        controller: :audio_events,
        action: :filter,
        defaults: {
            order_by: :created_at,
            direction: :desc
        }
    }
  end

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
    # @see http://stackoverflow.com/questions/24397640/rails-nested-includes-on-active-records
    # Note that includes works with association names while references needs the actual table name.
    # @see http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-includes
    query = AudioEvent
                .includes(:creator, :tags, audio_recording: [{site: [{projects: :permissions}]}])
                .references(:users, :tags, :audio_recordings, :sites, :projects, :permissions)
                .check_permissions(user)

    query = AudioEvent.filter_reference(query, params)
    query = AudioEvent.filter_tags(query, params)
    query = AudioEvent.filter_distance(query, params)
    query = AudioEvent.filter_user(query, params)
    query = AudioEvent.filter_audio_recording(query, params)
    query = AudioEvent.filter_paging(query, params)

    query = query.select('"audio_events".*, "audio_recordings"."recorded_date", "sites"."name", "sites"."id", "users"."user_name", "users"."id"')
    Rails.logger.info "AudioEvent filtered: #{query.to_sql}"
    query
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_tags(query, params)
    if params.include?(:tags_partial) && !params[:tags_partial].blank?
      tags_partial = CSV.parse(params[:tags_partial], col_sep: ',').flatten.map { |item| item.trim(' ', '') }.join('|').downcase
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
    if params.include?(:freq_min) || params.include?(:freq_max) || params.include?(:annotation_duration)
      compare_items = []
      compare_text = []

      if params.include?(:freq_min)
        compare_items.push(params[:freq_min].to_f)
        compare_text.push('power(audio_events.low_frequency_hertz - ?, 2)')
      end

      if params.include?(:freq_max)
        compare_items.push(params[:freq_max].to_f)
        compare_text.push('power(audio_events.high_frequency_hertz - ?, 2)')
      end

      if params.include?(:annotation_duration)
        compare_items.push(params[:annotation_duration].to_f)
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
    if params.include?(:user_id)
      creator_id_check = 'audio_events.creator_id = ?'
      updater_id_check = 'audio_events.updater_id = ?'
      user_id = params[:user_id].to_i
      query.where("(#{creator_id_check} OR #{updater_id_check})", user_id, user_id)
    else
      query
    end
  end

  # @param [ActiveRecord::Relation] query
  # @param [Hash] params
  def self.filter_audio_recording(query, params)
    if params.include?(:audio_recording_id) || params.include?(:audio_recording_id) || params.include?(:audiorecording_id)
      audio_recording_id = (params[:audio_recording_id] || params[:audio_recording_id] || params[:audiorecording_id]).to_i
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

  def self.csv_filter(user, filter_params)
    query = AudioEvent
                .includes(:creator, :tags, audio_recording: [{site: [{projects: :permissions}]}])
                .references(:users, :tags, :audio_recordings, :sites, :projects, :permissions)
                .check_permissions(user)

    if filter_params[:project_id]
      query = query.where(projects: {id: (filter_params[:project_id]).to_i})
    end

    if filter_params[:site_id]
      query = query.where(sites: {id: (filter_params[:site_id]).to_i})
    end

    if filter_params[:audio_recording_id] || filter_params[:audiorecording_d] || filter_params[:recording_id]
      query = query.where(audio_recordings: {id: (filter_params[:audio_recording_id] || filter_params[:audiorecording_d] || filter_params[:recording_id]).to_i})
    end

    if filter_params[:start_offset]
      query = query.end_after(filter_params[:start_offset])
    end

    if filter_params[:end_offset]
      query = query.start_before(filter_params[:end_offset])
    end

    query.order('audio_events.id DESC')
  end

  def get_listen_path
    segment_duration_seconds = 30
    offset_start_rounded = (self.start_time_seconds / segment_duration_seconds).floor * segment_duration_seconds
    offset_end_rounded = (self.end_time_seconds / segment_duration_seconds).floor * segment_duration_seconds
    offset_end_rounded += (offset_start_rounded == offset_end_rounded ? segment_duration_seconds : 0)

    "#{self.audio_recording.get_listen_path}?start=#{offset_start_rounded}&end=#{offset_end_rounded}"
  end

  def get_library_path
    "/library/#{self.audio_recording_id}/audio_events/#{self.id}"
  end

  def self.in_site(site)
    AudioEvent.find_by_sql(["SELECT ae.*
FROM audio_events ae
INNER JOIN audio_recordings ar ON ae.audio_recording_id = ar.id
INNER JOIN sites s ON ar.site_id = s.id
WHERE s.id = :site_id
ORDER BY ae.updated_at DESC
LIMIT 5", {site_id: site.id}])
  end

  private

  # custom validation methods
  def start_must_be_lte_end
    return unless end_time_seconds && start_time_seconds

    if start_time_seconds > end_time_seconds
      errors.add(:start_time_seconds, '%{value} must be lower than end time')
    end
  end

  def low_must_be_lte_high
    return unless high_frequency_hertz && low_frequency_hertz

    if low_frequency_hertz > high_frequency_hertz
      errors.add(:start_time_seconds, '%{value} must be lower than high frequency')
    end
  end

  def set_tags

    # for each tagging, check if a tag with that text already exists
    # if one does, delete that tagging and add the existing tag

    tag_ids_to_add = []

    self.taggings.each do |tagging|
      tag = tagging.tag
      # ensure string comparison is case insensitive
      existing_tag = Tag.where('lower(text) = ?', tag.text.downcase).first

      unless existing_tag.blank?
        #remove the tag association, otherwise it tries to create the tag and fails (as the tag already exists)
        self.tags.each do |audio_event_tag|
          # The collection.delete method removes one or more objects from the collection by setting their foreign keys to NULL.
          # ensure string comparison is case insensitive
          self.tags.delete(audio_event_tag) if existing_tag.text.downcase == audio_event_tag.text.downcase
        end

        # remove the tagging association
        self.taggings.delete(tagging)

        # record the tag id
        tag_ids_to_add.push(existing_tag.id)
      end
    end

    # add the tagging using the existing tag id
    tag_ids_to_add.each do |tag_id|
      self.taggings << Tagging.new(tag_id: tag_id)
    end

  end

end