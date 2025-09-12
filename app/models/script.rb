# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                                                                                                                   :integer          not null, primary key
#  analysis_identifier(a unique identifier for this script in the analysis system, used in directory names. [-a-z0-0_]) :string           not null
#  description                                                                                                          :string
#  event_import_glob(Glob pattern to match result files that should be imported as audio events)                        :string
#  event_import_minimum_score(Minimum score threshold for importing events, if any)                                     :decimal(, )
#  executable_command                                                                                                   :text             not null
#  executable_settings                                                                                                  :text
#  executable_settings_media_type                                                                                       :string(255)      default("text/plain")
#  executable_settings_name                                                                                             :string
#  name                                                                                                                 :string           not null
#  resources(Resources required by this script in the PBS format.)                                                      :jsonb
#  verified                                                                                                             :boolean          default(FALSE)
#  version(Version of this script - not the version of program the script runs!)                                        :integer          default(1), not null
#  created_at                                                                                                           :datetime         not null
#  creator_id                                                                                                           :integer          not null
#  group_id                                                                                                             :integer
#  provenance_id                                                                                                        :integer
#
# Indexes
#
#  index_scripts_on_creator_id     (creator_id)
#  index_scripts_on_group_id       (group_id)
#  index_scripts_on_provenance_id  (provenance_id)
#
# Foreign Keys
#
#  fk_rails_...           (provenance_id => provenances.id)
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#
class Script < ApplicationRecord
  # DEFAULT_SCRIPT_NAME = 'default'
  # DEFAULT_SCRIPT_IDENTIFIER = 'default'

  # Allow only lowercase latin letters, numbers, hyphens and underscores.
  # Must start an end with a letter or number.
  VALID_ANALYSIS_IDENTIFIER = /\A[a-z0-9][-a-z0-9_]*(?<![-_])\z/

  # relationships
  belongs_to :creator, class_name: 'User', inverse_of: :created_scripts
  belongs_to :provenance, inverse_of: :scripts, optional: true

  has_many :analysis_jobs_scripts, dependent: :restrict_with_exception
  has_many :analysis_jobs, through: :analysis_jobs_scripts, inverse_of: :scripts

  has_many :analysis_jobs_items, inverse_of: :script, dependent: :restrict_with_exception

  # attribute validations
  validates :name, :analysis_identifier, :executable_command,
    presence: true, length: { minimum: 2 }
  validates :executable_command, presence: true, length: { minimum: 2 }

  validates :analysis_identifier,
    presence: true,
    format: { with: VALID_ANALYSIS_IDENTIFIER },
    length: { in: 2..255 },
    uniqueness: {
      conditions: ->(script) { where.not(group_id: script.group_id) },
      message: 'must be unique (can be the same within a group)'
    }

  validates :provenance, presence: true
  validates :event_import_minimum_score, allow_nil: true, numericality: true

  #validates :resources, json: { message: ->(errors) { errors }, schema: Api::Schema::RESOURCES_PATH }
  validate :check_version_increase, on: :create

  validate :check_executable_command
  validate :executable_command_has_safe_characters

  validate :settings_are_consistent
  validate :executable_command_does_not_use_settings_when_not_provided

  validate :score_minimum_only_set_with_glob

  # A filesystem safe version of a name.
  # E.g. "Analysis Programs Acoustic Indices" -> "ap-indices"
  # @!attribute [rw] analysis_identifier
  #   @return [String]

  # override default attribute so we can use our struct as the default converter
  # @!attribute [rw] resources
  #   @return [::BawWorkers::BatchAnalysis::DynamicResourceList]
  attribute :resources, ::BawWorkers::ActiveRecord::Type::DomainModelAsJson.new(
    target_class: ::BawWorkers::BatchAnalysis::DynamicResourceList,
    ignore_nil: false
  )

  # for the first script in a group, make sure group_id is set to the script's id
  after_create :set_group_id

  # # Return the default Script ID
  # # @return [Integer]
  # def self.default_script_id
  #   @default_script_id ||= Script.where(name: DEFAULT_SCRIPT_NAME).pluck(:id).first
  # end

  # # Return the default Script
  # # @return [Script]
  # def self.default_script
  #   @default_script ||= Script.where(name: DEFAULT_SCRIPT_NAME).first
  # end

  def display_name
    "#{name} - v. #{version}"
  end

  def self.provenance_version_arel
    @provenance_version_arel ||= Arel.grouping(
      Provenance
      .arel_table
      .project(Provenance.arel_table[:version])
      .where(Provenance.arel_table[:id].eq(Script.arel_table[:provenance_id]))
      .ast
    ).freeze
  end

  def self.analysis_identifier_and_version_arel
    arel_table[:analysis_identifier]
      .concat(Arel::Nodes.build_quoted('_'))
      .concat(provenance_version_arel)
  end

  def self.analysis_identifier_and_latest_version_arel
    arel_table[:analysis_identifier]
      .concat(Arel::Nodes.build_quoted('_latest'))
  end

  def self.name_and_version_arel
    arel_table[:name]
      .concat(Arel::Nodes.build_quoted(' ('))
      .concat(provenance_version_arel)
      .concat(Arel::Nodes.build_quoted(')'))
  end

  def self.name_and_latest_version_arel
    arel_table[:name].concat(' (latest)')
  end

  def self.latest_version_condition_arel
    max_table = Arel::Table.new(arel_table.table_name, as: 'max_version_scripts')

    arel_table[:version].eq(
      max_table
          .project(max_table[:version].maximum)
          .where(max_table[:analysis_identifier].eq(arel_table[:analysis_identifier]))
    )
  end

  def self.latest_version_case_statement_arel(true_case, false_case = Arel.null)
    latest_version_condition_arel
      .when(Arel.true).then(true_case)
      .else(false_case)
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

    # prioritize value from db query
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

    # prioritize value from db query
    read_attribute(:first_version) || @first_version
  end

  def is_first_version?
    version == first_version
  end

  # override the default query for the model
  def self.default_scope
    query = <<-SQL.squish
    INNER JOIN (
      SELECT "group_id", max("version") AS "last_version", min("version") AS "first_version"
      FROM "scripts"
      GROUP BY "group_id"
    ) s2 on ("scripts"."group_id" = "s2"."group_id")
    SQL

    joins(query).select('"scripts".*', '"scripts".id', '"s2"."last_version"', '"s2"."first_version"')
  end

  # a fake reference to the aliased table defined in the default scope
  @script_group = Arel::Table.new('s2')

  def all_versions
    Script.where(group_id:).order(created_at: :desc)
  end

  def self.filter_settings
    {
      valid_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
                     :executable_settings_name, :executable_command, :executable_settings,
                     :version, :created_at, :creator_id, :is_last_version, :is_first_version,
                     :is_last_version, :is_first_version, :event_import_glob, :provenance_id, :event_import_minimum_score],
      render_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings,
                      :executable_settings_media_type,
                      :executable_settings_name, :executable_command,
                      :version, :created_at, :creator_id,
                      :is_last_version, :is_first_version, :event_import_glob, :provenance_id, :resources, :event_import_minimum_score],
      text_fields: [:name, :description, :analysis_identifier, :executable_settings_media_type,
                    :executable_settings_name, :executable_command, :executable_settings],
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
        executable_command: { type: 'string' },
        executable_settings: { type: 'string' },
        executable_settings_name: { type: 'string' },
        executable_settings_media_type: { type: 'string' },
        version: { type: 'number' },
        **Api::Schema.creator_user_stamp,
        is_last_version: { type: 'boolean', readOnly: true },
        is_first_version: { type: 'boolean', readOnly: true },
        event_import_glob: { type: 'string', readOnly: true },
        event_import_minimum_score: { type: ['number', 'null'], format: 'float', readOnly: true },
        provenance_id: Api::Schema.id(read_only: false),
        resources: { '$ref' => '#/components/schemas/resources' }
      },
      required: [
        :id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
        :executable_settings_name, :executable_command, :executable_settings,
        :version, :created_at, :creator_id, :is_last_version, :is_first_version,
        :event_import_glob, :provenance_id, :executable_command
      ]
    }.freeze
  end

  private

  def check_version_increase
    matching_or_higher_versions =
      Script
        .unscoped
        .where(group_id:)
        .where(version: version..)

    return unless matching_or_higher_versions.count.positive?

    errors.add(
      :version,
      "must be higher than previous versions (#{matching_or_higher_versions.pluck(:version).flatten.join(', ')})"
    )
  end

  def check_executable_command
    # blank validation handled by other validators
    return if executable_command.blank?

    # just need to provide the values, they don't need to be real to validate
    # the command value
    values = BawWorkers::BatchAnalysis::CommandTemplater::ALL.index_with { |_| 'value' }

    begin
      BawWorkers::BatchAnalysis::CommandTemplater.format_command(
        executable_command,
        values
      )
    rescue ArgumentError => e
      errors.add(:executable_command, e.message)
    end
  end

  # all control characters except for tab and newline
  # Window style new-lines in particular will break the bash scripts that run the
  # commands.
  UNSAFE_EXECUTABLE_COMMAND_CHARACTERS = /(?![\n\t])[\p{Cc}\p{Cf}\p{Cn}\p{Co}]/
  def executable_command_has_safe_characters
    return if executable_command.blank?

    return unless executable_command.match?(UNSAFE_EXECUTABLE_COMMAND_CHARACTERS)

    errors.add(:executable_command, 'contains unsafe characters')
  end

  def executable_command_does_not_use_settings_when_not_provided
    return unless executable_settings.nil?

    config_tokens = BawWorkers::BatchAnalysis::CommandTemplater::CONFIG_PLACEHOLDERS

    regex = "{#{config_tokens.join('|')}}"

    return unless executable_command&.match?(regex)

    errors.add(:executable_command,
      "contains one of #{config_tokens.format_inline_list} but no settings are provided")
  end

  def settings_are_consistent
    return if !executable_settings.nil? && executable_settings_name.present? && executable_settings_media_type.present?

    # we want to allow empty but present settings, but the others must have non-blank values
    return if executable_settings.nil? && executable_settings_name.blank? && executable_settings_media_type.blank?

    errors.add(:base, 'executable settings, name, and media type must all be present or all be blank')
  end

  def score_minimum_only_set_with_glob
    return if event_import_glob.present? || event_import_minimum_score.nil?

    errors.add(:event_import_minimum_score, 'can only be set when event_import_glob is also set')
  end

  def set_group_id
    return if group_id.present?

    self.group_id = id
    save!
  end
end
