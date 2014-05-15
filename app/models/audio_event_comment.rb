class AudioEventComment < ActiveRecord::Base
  extend Enumerize

  attr_accessible :audio_event_id, :comment, :flag

  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_audio_event_comments
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_audio_event_comments
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_audio_event_comments
  belongs_to :flagger, class_name: 'User', foreign_key: :flagger_id, inverse_of: :flagged_audio_event_comments

  belongs_to :audio_event, inverse_of: :audio_event_comments

  # add created_at and updated_at stamper
  stampable

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # enums
  AVAILABLE_FLAGS_SYMBOLS = [:report]
  AVAILABLE_FLAGS = AVAILABLE_FLAGS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_FLAGS_DISPLAY = [
      {id: :report, name: 'Report'},
  ]

  enumerize :flag, in: AVAILABLE_FLAGS, predicates: true

  # validations
  validates :comment, presence: true, length: {minimum: 2}

  # scopes
  scope :check_permissions, lambda { |user|
    if user.is_admin?
      where('1 = 1') # don't change query
    else
      creator_id_check = 'projects.creator_id = ?'
      permissions_check = '(permissions.user_id = ? AND permissions.level IN (\'reader\', \'writer\'))'
      where("#{creator_id_check} OR #{permissions_check}", user.id, user.id)
    end
  }

  def self.filtered(user, audio_event, params)

    query = AudioEventComment.includes([:creator, audio_event: {audio_recording: {site: {projects: :permissions}}}])

    unless audio_event.blank?
      query = query.where(audio_event_id: audio_event.id)
    end

    query = query.check_permissions(user)

    page = AudioEventComment.filter_count(params, :page, 1, 1)
    items = AudioEventComment.filter_count(params, :items, 1, 30)
    query = query.offset((page - 1) * items).limit(items)

    # keep comments in order they were created
    order_by_coalesce = 'COALESCE(audio_event_comments.created_at, audio_event_comments.updated_at) DESC'

    query = query.order(order_by_coalesce)
    #puts query.to_sql
    query
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

end
