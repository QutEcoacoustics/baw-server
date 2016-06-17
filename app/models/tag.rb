class Tag < ActiveRecord::Base
  extend Enumerize

  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  has_many :taggings, inverse_of: :tag
  has_many :audio_events, through: :taggings
  has_many :tag_groups, inverse_of: :tag
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_tags
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_tags

  accepts_nested_attributes_for :audio_events

  # enums
  AVAILABLE_TYPE_OF_TAGS_SYMBOLS = [:general, :common_name, :species_name, :looks_like, :sounds_like]
  AVAILABLE_TYPE_OF_TAGS = AVAILABLE_TYPE_OF_TAGS_SYMBOLS.map { |item| item.to_s }

  AVAILABLE_TYPE_OF_TAGS_DISPLAY = [
      {id: :general, name: 'General'},
      {id: :common_name, name: 'Common Name'},
      {id: :species_name, name: 'Scientific Name'},
      {id: :looks_like, name: 'Looks like'},
      {id: :sounds_like, name: 'Sounds Like'},
  ]

  enumerize :type_of_tag, in: AVAILABLE_TYPE_OF_TAGS, predicates: true

  # association validations
  validates :creator, existence: true

  # attribute validations
  validates :is_taxanomic, inclusion: {in: [true, false]}
  validates :text, uniqueness: {case_sensitive: false}, presence: true
  validates :retired, inclusion: {in: [true, false]}
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
    if self.type_of_tag == 'common_name' || self.type_of_tag == 'species_name'
      errors.add(:is_taxanomic, "must be true for #{self.type_of_tag}") unless self.is_taxanomic
    else
      errors.add(:is_taxanomic, "must be false for #{self.type_of_tag}") if self.is_taxanomic
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
limit 10', {user_id: user.id}])
    Tag.connection.select_all(query)
  end

  # @param [Tag] tags
  def self.get_priority_tag(tags)

    return nil if tags.size < 1

    first = tags.first
    return first if first.type_of_tag.to_s == 'common_name'

    first_common = nil
    first_species = nil
    first_other = nil
    tags.each do |tag|
      first_common = tag if tag.type_of_tag == 'common_name' && first_common == nil
      first_species = tag if tag.type_of_tag == 'species_name' && first_common == nil
      first_other = tag if first_other == nil
    end

    first_common || first_species || first_other
  end

  # Define filter api settings
  def self.filter_settings
    {
        valid_fields: [
            :id, :text, :is_taxanomic, :type_of_tag, :retired, :notes,
            :creator_id, :created_at, :updater_id, :updated_at
        ],
        render_fields: [:id, :text, :is_taxanomic, :type_of_tag, :retired],
        text_fields: [:text, :type_of_tag, :notes],
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
