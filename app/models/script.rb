# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                             :integer          not null, primary key
#  analysis_action_params         :json
#  analysis_identifier            :string           not null
#  description                    :string
#  executable_command             :text             not null
#  executable_settings            :text             not null
#  executable_settings_media_type :string(255)      default("text/plain")
#  name                           :string           not null
#  verified                       :boolean          default(FALSE)
#  version                        :decimal(4, 2)    default(0.1), not null
#  created_at                     :datetime         not null
#  creator_id                     :integer          not null
#  group_id                       :integer
#
# Indexes
#
#  index_scripts_on_creator_id  (creator_id)
#  index_scripts_on_group_id    (group_id)
#
# Foreign Keys
#
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#
class Script < ApplicationRecord
  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_scripts
  has_many :analysis_jobs, inverse_of: :script

  # association validations
  #validates_associated :creator

  # attribute validations
  validates :analysis_action_params, json: { message: 'Must be valid JSON' }

  validates :name, :analysis_identifier, :executable_command, :executable_settings, :executable_settings_media_type,
    presence: true, length: { minimum: 2 }
  validate :check_version_increase, on: :create

  # for the first script in a group, make sure group_id is set to the script's id
  after_create :set_group_id

  def display_name
    "#{name} - v. #{version}"
  end

  def latest_version
    Script
      .where(group_id:)
      .order(version: :desc)
      .first
  end

  def earliest_version
    Script
      .where(group_id:)
      .order(version: :asc)
      .first
  end

  def last_version
    if !@last_version && !has_attribute?(:last_version)
      @last_version = Script
                      .where(group_id:)
                      .maximum(:version)
    end

    # prioritise value from db query
    read_attribute(:last_version) || @last_version
  end

  def is_last_version?
    version == last_version
  end

  def first_version
    if !@first_version && !has_attribute?(:first_version)
      @first_version = Script
                       .where(group_id:)
                       .minimum(:version)
    end

    # prioritise value from db query
    read_attribute(:first_version) || @first_version
  end

  def is_first_version?
    version == first_version
  end

  # override the default query for the model
  def self.default_scope
    query = <<-SQL
    INNER JOIN (
      SELECT "group_id", max("version") AS "last_version", min("version") AS "first_version"
      FROM "scripts"
      GROUP BY "group_id"
    ) s2 on ("scripts"."group_id" = "s2"."group_id")
    SQL

    joins(query).select('"scripts".*, "s2"."last_version", "s2"."first_version"')
  end

  # a fake reference to the aliased table defined in the default scope
  @script_group = Arel::Table.new('s2')

  def all_versions
    Script.where(group_id:).order(created_at: :desc)
  end

  def self.filter_settings
    {
      valid_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
                     :version, :created_at, :creator_id, :is_last_version, :is_first_version, :analysis_action_params,
                     :is_last_version, :is_first_version],
      render_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings,
                      :executable_settings_media_type, :version, :created_at, :creator_id, :analysis_action_params,
                      :is_last_version, :is_first_version],
      text_fields: [:name, :description, :analysis_identifier, :executable_settings_media_type,
                    :analysis_action_params],
      custom_fields: lambda { |item, _user|
                       virtual_fields = {
                         **item.render_markdown_for_api_for(:description)
                       }
                       [item, virtual_fields]
                     },
      custom_fields2: {
        is_last_version: {
          query_attributes: [],
          # HACK: calculate the definition virtually as well because calculated
          # fields are not yet returned in single object responses
          # https://github.com/QutEcoacoustics/baw-server/issues/565
          transform: ->(item) { item.is_last_version? },
          arel: Arel::Nodes::Grouping.new(
            Arel::Nodes::InfixOperation.new(
              :'=',
              @script_group[:last_version],
              Script.arel_table[:version]
            )
          ),
          type: :boolean
        },
        is_first_version: {
          query_attributes: [],
          # HACK: calculate the definition virtually as well because calculated
          # fields are not yet returned in single object responses
          # https://github.com/QutEcoacoustics/baw-server/issues/565
          transform: ->(item) { item.is_first_version? },
          arel: Arel::Nodes::Grouping.new(
            Arel::Nodes::InfixOperation.new(
              :'=',
              @script_group[:first_version],
              Script.arel_table[:version]
            )
          ),
          type: :boolean
        }
      },
      controller: :scripts,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      }
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        group_id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        analysis_identifier: { type: 'string' },
        executable_settings: { type: 'string' },
        executable_settings_media_type: { type: 'string' },
        version: { type: 'number' },
        **Api::Schema.creator_user_stamp,
        is_last_version: { type: 'boolean', readOnly: true },
        is_first_version: { type: 'boolean', readOnly: true },
        analysis_action_params: { type: 'object' }
      },
      required: [
        :id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
        :version, :created_at, :creator_id, :is_last_version, :is_first_version, :analysis_action_params
      ]
    }.freeze
  end

  private

  def check_version_increase
    matching_or_higher_versions =
      Script
      .unscoped
      .where(group_id:)
      .where('version >= ?', version)
    if matching_or_higher_versions.count.positive?
      errors.add(:version,
        "must be higher than previous versions (#{matching_or_higher_versions.pluck(:version).flatten.join(', ')})")
    end
  end

  def set_group_id
    if group_id.blank?
      self.group_id = id
      save!
    end
  end
end
