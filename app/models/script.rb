# frozen_string_literal: true

class Script < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_scripts
  has_many :analysis_jobs, inverse_of: :script

  # association validations
  validates :creator, existence: true

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
      .where(group_id: group_id)
      .order(version: :desc)
      .first
  end

  def earliest_version
    Script
      .where(group_id: group_id)
      .order(version: :asc)
      .first
  end

  def last_version
    if !@last_version && !has_attribute?(:last_version)
      @last_version = Script
                      .where(group_id: group_id)
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
                       .where(group_id: group_id)
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
    Script.where(group_id: group_id).order(created_at: :desc)
  end

  def self.filter_settings
    {
      valid_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
                     :version, :created_at, :creator_id, :is_last_version, :is_first_version, :analysis_action_params],
      render_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings,
                      :executable_settings_media_type, :version, :created_at, :creator_id],
      text_fields: [:name, :description, :analysis_identifier, :executable_settings_media_type, :analysis_action_params],
      custom_fields: lambda { |item, _user|
                       virtual_fields = {
                         is_last_version: item.is_last_version?,
                         is_first_version: item.is_first_version?
                       }
                       [item, virtual_fields]
                     },
      field_mappings: [
        {
          name: :is_last_version,
          value: Arel::Nodes::Grouping.new(
            Arel::Nodes::InfixOperation.new(
              '='.to_sym,
              @script_group[:last_version],
              Script.arel_table[:version]
            )
          )
        },
        {
          name: :is_first_version,
          value: Arel::Nodes::Grouping.new(
            Arel::Nodes::InfixOperation.new(
              '='.to_sym,
              @script_group[:first_version],
              Script.arel_table[:version]
            )
          )
        }
      ],
      controller: :scripts,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      }
    }
  end

  private

  def check_version_increase
    matching_or_higher_versions =
      Script
      .unscoped
      .where(group_id: group_id)
      .where('version >= ?', version)
    if matching_or_higher_versions.count > 0
      errors.add(:version, "must be higher than previous versions (#{matching_or_higher_versions.pluck(:version).flatten.join(', ')})")
    end
  end

  def set_group_id
    if group_id.blank?
      self.group_id = id
      save!
    end
  end
end
