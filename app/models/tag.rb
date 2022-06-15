# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id           :integer          not null, primary key
#  is_taxonomic :boolean          default(FALSE), not null
#  notes        :jsonb
#  retired      :boolean          default(FALSE), not null
#  text         :string           not null
#  type_of_tag  :string           default("general"), not null
#  created_at   :datetime
#  updated_at   :datetime
#  creator_id   :integer          not null
#  updater_id   :integer
#
# Indexes
#
#  index_tags_on_creator_id  (creator_id)
#  index_tags_on_updater_id  (updater_id)
#  tags_text_uidx            (text) UNIQUE
#
# Foreign Keys
#
#  tags_creator_id_fk  (creator_id => users.id)
#  tags_updater_id_fk  (updater_id => users.id)
#
class Tag < ApplicationRecord
  extend Enumerize

  # relations
  has_many :taggings, inverse_of: :tag
  has_many :audio_events, through: :taggings
  has_many :tag_groups, inverse_of: :tag
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_tags
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_tags, optional: true

  accepts_nested_attributes_for :audio_events

  # enums
  AVAILABLE_TYPE_OF_TAGS_SYMBOLS = [:general, :common_name, :species_name, :looks_like, :sounds_like].freeze
  AVAILABLE_TYPE_OF_TAGS = AVAILABLE_TYPE_OF_TAGS_SYMBOLS.map(&:to_s)

  AVAILABLE_TYPE_OF_TAGS_DISPLAY = [
    { id: :general, name: 'General' },
    { id: :common_name, name: 'Common Name' },
    { id: :species_name, name: 'Scientific Name' },
    { id: :looks_like, name: 'Looks like' },
    { id: :sounds_like, name: 'Sounds Like' }
  ].freeze

  enumerize :type_of_tag, in: AVAILABLE_TYPE_OF_TAGS, predicates: true

  # association validations
  #validates_associated :creator

  # attribute validations
  validates :is_taxonomic, inclusion: { in: [true, false] }
  validates :text, uniqueness: { case_sensitive: false }, presence: true
  validates :retired, inclusion: { in: [true, false] }
  validates :type_of_tag, presence: true
  validate :taxonomic_enforced

  # http://stackoverflow.com/questions/11569940/inclusion-validation-fails-when-provided-a-symbol-instead-of-a-string
  # this lets a symbol be set, and it all still works
  def type_of_tag=(new_type_of_tag)
    super new_type_of_tag.to_s
  end

  # order by number of audio recordings associated with a tag
  #Tag.joins(:taggings).select('tags.*, count(tag_id) as "tag_count"').group(:tag_id).order(' tag_count desc')

  def taxonomic_enforced
    if type_of_tag == 'common_name' || type_of_tag == 'species_name'
      errors.add(:is_taxonomic, "must be true for #{type_of_tag}") unless is_taxonomic
    elsif is_taxonomic
      errors.add(:is_taxonomic, "must be false for #{type_of_tag}")
    end
  end

  def self.user_top_tags(user)
    query = sanitize_sql_array(
      ['select (select tags.text from tags where tags.id = audio_events_tags.tag_id) as tag_name, count(*) as tag_count
      from audio_events_tags
      inner join tags on audio_events_tags.tag_id = tags.id
      where audio_events_tags.creator_id = :user_id
      group by audio_events_tags.tag_id
      order by count(*) DESC
      limit 10', { user_id: user.id }]
    )
    Tag.connection.select_all(query)
  end

  # @param [Tag] tags
  def self.get_priority_tag(tags)
    return nil if tags.empty?

    first = tags.first
    return first if first.type_of_tag == 'common_name'

    first_common = nil
    first_species = nil
    first_other = nil
    tags.each do |tag|
      first_common = tag if tag.type_of_tag == 'common_name' && first_common.nil?
      first_species = tag if tag.type_of_tag == 'species_name' && first_common.nil?
      first_other = tag if first_other.nil?
    end

    first_common || first_species || first_other
  end

  def self.first_with_text(text)
    Tag.where(arel_table[:text].imatches(text)).first
  end

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [
        :id, :text, :is_taxonomic, :type_of_tag, :retired, :notes,
        :creator_id, :created_at, :updater_id, :updated_at
      ],
      render_fields: [
        :id, :text, :is_taxonomic, :type_of_tag, :retired, :notes, :creator_id,
        :updater_id, :created_at, :updated_at
      ],
      text_fields: [:text, :type_of_tag, :notes],
      new_spec_fields: lambda { |_user|
        {
          text: nil,
          is_taxonomic: false,
          type_of_tag: nil,
          retired: false,
          notes: nil
        }
      },
      controller: :tags,
      action: :filter,
      defaults: {
        order_by: :text,
        direction: :asc
      },
      valid_associations: [
        {
          join: Tagging,
          on: Tag.arel_table[:id].eq(Tagging.arel_table[:tag_id]),
          available: true,
          associations: [
            {
              join: AudioEvent,
              on: Tagging.arel_table[:audio_event_id].eq(AudioEvent.arel_table[:id]),
              available: true
            }
          ]
        }
      ]
    }
  end
end
