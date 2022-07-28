# frozen_string_literal: true

# when HarvestItem is used in the context of a job, it does not have access to
# rails' normal autoloader... for some reason?
require(BawApp.root / 'app/serializers/hash_serializer')

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  deleted            :boolean          default(FALSE)
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  harvest_id         :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_path    (path)
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (harvest_id => harvests.id)
#  fk_rails_...  (uploader_id => users.id)
#
class HarvestItem < ApplicationRecord
  extend Enumerize
  # optional audio recording - when a harvested audio file is complete, it will match a recording
  belongs_to :audio_recording, optional: true

  # harvests were introduced after harvest_items, hence the parent association is optional
  belongs_to :harvest, optional: true

  belongs_to :uploader, class_name: User.name, foreign_key: :uploader_id

  validates :path, presence: true, length: { minimum: 2 }, format: {
    # don't allow paths that start with a `/`
    # \A matches the start of a string in a non-multiline regex
    with: %r{\A(?!/).*}
  }

  # we know there's a file on disk we have to deal with
  STATUS_NEW = :new
  # we've analyzed the file, gotten the metadata, and validated.
  # If the file has fixable mistakes they can be changed by the user here
  # (e.g. missing utc offset / site_id for a folder)
  STATUS_METADATA_GATHERED = :metadata_gathered
  # he file is not valid for some reason we now about (missing utc offset which the user didn't fix)
  STATUS_FAILED = :failed
  # successfully harvested the file, there will be an audio_recording that is available now
  STATUS_COMPLETED = :completed
  # there was an unexpected error or bug encountered while harvesting
  STATUS_ERRORED = :errored
  STATUSES = [STATUS_NEW, STATUS_METADATA_GATHERED, STATUS_FAILED, STATUS_COMPLETED, STATUS_ERRORED].freeze

  enumerize :status, in: STATUSES, default: :new

  # override default attribute so we can use our struct as the default converter
  # @!attribute [rw] info
  # @return [::BawWorkers::Jobs::Harvest::Info]
  attribute :info, ::BawWorkers::ActiveRecord::Type::DomainModelAsJson.new(
      target_class: ::BawWorkers::Jobs::Harvest::Info
    )

  def new?
    status == STATUS_NEW
  end

  def metadata_gathered?
    status == STATUS_METADATA_GATHERED
  end

  def failed?
    status == STATUS_FAILED
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def errored?
    status == STATUS_ERRORED
  end

  def terminal_status?
    completed? || failed? || errored?
  end

  def metadata_gathered_or_unsuccessful?
    metadata_gathered? || errored? || failed?
  end

  def file_deleted?
    deleted
  end

  # Deletes the file located at the path this harvest_item represents.
  # Use this after a successful harvest.

  def delete_file!(completed_only: true)
    return if deleted?

    return unless completed? || !completed_only

    absolute_path.delete if absolute_path.exist?
    self.deleted = true
  end

  def self.find_by_path_and_harvest(path, harvest)
    find_by path:, harvest_id: harvest.id
  end

  # @return [Pathname]
  def absolute_path
    Settings.root_to_do_path / path
  end

  # @return [String, nil]
  def path_relative_to_harvest
    return if harvest.nil?

    harvest_prefix = "#{harvest.upload_directory_name}/"
    path.delete_prefix(harvest_prefix)
  end

  def add_to_error(message)
    self.info = info.new(error: "#{info.error}\n#{message}")
  end

  # Queries the database to see if any other items overlaps with this harvest item
  # By default only returns first 10 items.
  # @return [Array<HarvestItem>]
  def overlaps_with
    recorded_date = info.file_info[:recorded_date]
    duration_seconds = info.file_info[:duration_seconds]
    site_id = info.file_info[:site_id]

    [:recorded_date, :duration_seconds, :site_id].each do |key|
      raise ArgumentError, "#{key} cannot be blank" if binding.local_variable_get(key).blank?
    end

    other_recorded_date = "(info->'file_info'->>'recorded_date')::timestamptz"
    other_duration_seconds = "(info->'file_info'->>'duration_seconds')::numeric"
    other_site_id = "(info->'file_info'->>'site_id')::numeric"

    this_term = "('#{recorded_date}'::timestamptz, (#{duration_seconds} * '1 second'::interval))"
    other_term = "(#{other_recorded_date}, (#{other_duration_seconds} * '1 second'::interval))"

    HarvestItem.where(HarvestItem.arel_table[:id] != id)
               .where(HarvestItem.arel_table[:harvest_id] == harvest_id)
               .where("#{site_id} = #{other_site_id}")
               .where("#{this_term} OVERLAPS #{other_term}")
               .limit(10)
               .to_a
  end

  def duplicate_hash_of
    file_hash = info.file_info[:file_hash]

    HarvestItem
      .where(HarvestItem.arel_table[:id] != id)
      .where(HarvestItem.arel_table[:harvest_id] == harvest_id)
      .where(harvest_id:)
      .where("info->'file_info'->>'file_hash' = '#{file_hash}'")
      .limit(10)
  end

  def self.size_arel
    Arel.sql("(info->'file_info'->>'data_length_bytes')::bigint")
  end

  def self.duration_arel
    Arel.sql("(info->'file_info'->>'duration_seconds')::numeric")
  end

  def self.validations_arel
    Arel.sql("(info->'validations')::jsonb")
  end

  # Arel for returning whether or not this harvest item is not fixable
  # SQL values returned are:
  #   - 1: this harvest item has non-fixable validations
  #   - 0: this harvest item has fixable validations or no validations
  # @return [Arel::Nodes::Grouping]
  def self.invalid_not_fixable_arel
    n = BawWorkers::Jobs::Harvest::ValidationResult::STATUS_NOT_FIXABLE
    Arel.sql(
      <<~SQL
        COALESCE((
            SELECT bool_or(status = '#{n}')
            FROM jsonb_to_recordset(info->'validations') AS statuses(status text)
          )::integer, 0)
      SQL
    )
  end

  # Arel for returning whether or not this harvest item is fixable
  # SQL values returned are:
  #   - 1: this harvest item has fixable validations
  #   - 0: this harvest item has non-fixable validations or no validations
  # @return [Arel::Nodes::Grouping]
  def self.invalid_fixable_arel
    f = BawWorkers::Jobs::Harvest::ValidationResult::STATUS_FIXABLE
    Arel.sql(
      <<~SQL
        COALESCE((
            SELECT every(status = '#{f}')
            FROM jsonb_to_recordset(info->'validations') AS statuses(status text)
          )::integer, 0)
      SQL
    )
  end

  # Arel for returning whether or not this harvest item is valid
  # SQL values returned are:
  #   - 1: this harvest item has no validation errors
  #   - 0: this harvest item has some validation errors
  # @return [Arel::Nodes::Grouping]
  def self.valid_arel
    Arel.sql(
      <<~SQL
        COALESCE((jsonb_array_length(info->'validations') = 0)::integer, 1)
      SQL
    )
  end

  DEFAULT_COUNTS_BY_STATUS = STATUSES.map(&:to_s).product([0]).to_h
  def self.counts_by_status(relation)
    DEFAULT_COUNTS_BY_STATUS.merge(relation.group(:status).count)
  end

  # When we return fake harvest items that are directories, the id is nil
  def pseudo_directory?
    id.nil?
  end

  # @param query [ActiveRecord::Relation] the current HarvestItem query
  # @param path [String] the path to filter by
  # @return [ActiveRecord::Relation]
  def self.project_directory_listing(relation, path_query)
    raise ArgumentError, 'query must be an ActiveRecord::Relation' unless relation.is_a?(ActiveRecord::Relation)

    path_query = path_query.trim('/')
    path_query_bind = Arel::Nodes.build_quoted(path_query)

    table = HarvestItem.arel_table
    harvest_id_name = table[:harvest_id].name
    all_columns = HarvestItem.columns.map(&:name)

    base_query_table = Arel::Table.new('base_query')
    with_dir_columns_table = Arel::Table.new('with_dir_columns')
    list_query_table = Arel::Table.new('list_query')

    dir_col = 'dir'
    current_dir_col = 'current_dir'

    with_dir_columns = base_query_table.project(
      Arel.star,
      Arel::Nodes::NamedFunction.new('dirname', [base_query_table[:path]]).as(dir_col),
      Arel::Nodes::NamedFunction.new(
        'path_contained_by_query', [
          Arel::Nodes::NamedFunction.new('dirname', [base_query_table[:path]]),
          path_query_bind
        ]
      ).as(current_dir_col)
    )

    # these mirror the values produced by Harvest.generate_report
    dir_status_cols = [
      Arel.star.count.as('items_total'),
      HarvestItem.size_arel.sum.as('items_size_bytes'),
      HarvestItem.duration_arel.sum.as('items_duration_seconds'),
      *(STATUSES.map { |s| Arel.star.count.filter(with_dir_columns_table['status'].eq(s)).as("items_#{s}") }),
      HarvestItem.invalid_fixable_arel.sum.as('items_invalid_fixable'),
      HarvestItem.invalid_not_fixable_arel.sum.as('items_invalid_not_fixable')
    ]
    file_status_cols = [
      Arel.sql('1').as('items_total'),
      HarvestItem.size_arel.as('items_size_bytes'),
      HarvestItem.duration_arel.as('items_duration_seconds'),
      *(STATUSES.map { |s| with_dir_columns_table['status'].eq(s).cast('int').as("items_#{s}") }),
      HarvestItem.invalid_fixable_arel.as('items_invalid_fixable'),
      HarvestItem.invalid_not_fixable_arel.as('items_invalid_not_fixable')
    ]

    dir_cols = all_columns.map { |col|
      case col
      when table[:path].name then with_dir_columns_table[current_dir_col].as(table[:path].name)
      when harvest_id_name then (with_dir_columns_table[harvest_id_name]).maximum.as(harvest_id_name)
      else Arel.null.as(col)
      end
    }

    # rubocop:disable Style/NonNilCheck, Naming/AsciiIdentifiers
    list_query = Arel::Nodes::Union.new(
      # child dirs
      with_dir_columns_table
        .where((with_dir_columns_table[current_dir_col] != nil).⋀(with_dir_columns_table[dir_col] != path_query_bind))
        .group(with_dir_columns_table[current_dir_col])
        .project(*dir_cols, *dir_status_cols),
      # child files
      with_dir_columns_table
        .where(with_dir_columns_table[dir_col] == path_query_bind)
        .project(*all_columns, *file_status_cols)
    )
    # rubocop:enable Style/NonNilCheck, Naming/AsciiIdentifiers

    HarvestItem
      .with(base_query: relation, with_dir_columns:, list_query:)
      .from(list_query_table.as(table.name))
      # sort directories first, then sort by path name
      .order(Arel.sql("(#{table[:id].name} IS NULL) DESC"))
  end

  def report
    {
      items_total:,
      items_size_bytes:,
      items_duration_seconds:,
      items_invalid_fixable:,
      items_invalid_not_fixable:,
      items_new:,
      items_metadata_gathered:,
      items_failed:,
      items_completed:,
      items_errored:
    }
  end

  def self.filter_settings
    filterable_fields = [
      :id, :deleted, :path, :status, :created_at, :harvest_id,
      :updated_at, :audio_recording_id, :uploader_id
    ]

    # terrible no good hack; but I can't work out how to customize filter per action
    # since filter_settings must be invocable statically, we can't customize with parameter.
    include_report = Current.action_name == 'filter' ? [] : [:report]

    {
      valid_fields: [*filterable_fields],
      render_fields: [
        *filterable_fields,
        *include_report,
        :validations
      ],
      text_fields: [],
      custom_fields2: {
        validations: {
          query_attributes: [],
          transform: ->(item) { item.pseudo_directory? ? nil : item.validations },
          arel: HarvestItem.validations_arel,
          type: :array
        },
        path: {
          query_attributes: [],
          transform: ->(item) { item.path_relative_to_harvest },
          arel: arel_table[:path],
          type: :string
        },
        report: {
          query_attributes: [:status, :info,
                             :items_total,
                             :items_size_bytes,
                             :items_duration_seconds,
                             :items_invalid_fixable,
                             :items_invalid_not_fixable,
                             :items_new,
                             :items_metadata_gathered,
                             :items_failed,
                             :items_completed,
                             :items_errored],
          transform: ->(item) { item.report },
          arel: nil,
          type: :hash
        }
      },
      new_spec_fields: ->(_user) { {} },
      controller: :harvest_items,
      action: :filter,
      defaults: {
        order_by: :path,
        direction: :asc
      },
      valid_associations: [
        {
          join: Harvest,
          on: HarvestItem.arel_table[:harvest_id].eq(Harvest.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.report_schema
    {
      report: {
        type: 'object',
        readOnly: true,
        properties: {
          items_total: { type: 'integer' },
          items_size_bytes: { type: ['null', 'integer'] },
          items_duration_seconds: { type: ['null', 'integer'] },
          items_invalid_fixable: { type: 'integer' },
          items_invalid_not_fixable: { type: 'integer' },
          items_new: { type: 'integer' },
          items_metadata_gathered: { type: 'integer' },
          items_failed: { type: 'integer' },
          items_completed: { type: 'integer' },
          items_errored: { type: 'integer' }
        }
      }
    }
  end

  def self.schema
    {
      type: :object,
      additionalProperties: false,
      properties: {
        id: Api::Schema.id(nullable: true),
        deleted: { type: 'boolean', readOnly: true },
        path: { type: 'string', readOnly: true },
        status: { type: 'string', enum: STATUSES, readOnly: true },
        created_at: Api::Schema.date(read_only: true),
        updated_at: Api::Schema.date(read_only: true),
        audio_recording_id: Api::Schema.id(nullable: true),
        uploader_id: Api::Schema.id(nullable: true),
        harvest_id: Api::Schema.id,
        validations: {
          type: 'array',
          readOnly: true,
          items: {
            type: 'object',
            additionalProperties: false,
            properties: {
              status: {
                type: 'string',
                readOnly: true,
                enum: [
                  BawWorkers::Jobs::Harvest::ValidationResult::STATUS_FIXABLE,
                  BawWorkers::Jobs::Harvest::ValidationResult::STATUS_NOT_FIXABLE
                ]
              },
              message: { type: 'string', readOnly: true },
              name: { type: 'string', readOnly: true }
            }
          }
        },
        **report_schema
      }
    }
  end
end
