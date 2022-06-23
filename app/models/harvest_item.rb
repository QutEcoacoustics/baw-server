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
               .where("#{site_id} = #{other_site_id}")
               .where("#{this_term} OVERLAPS #{other_term}")
               .limit(10)
               .to_a
  end

  def duplicate_hash_of
    file_hash = info.file_info[:file_hash]

    HarvestItem
      .where(HarvestItem.arel_table[:id] != id)
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
        (
          SELECT bool_or(status = '#{n}')
          FROM jsonb_to_recordset(info->'validations') AS statuses(status text)
        )::integer
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
        (
          SELECT every(status = '#{f}')
          FROM jsonb_to_recordset(info->'validations') AS statuses(status text)
        )::integer
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
        (jsonb_array_length(info->'validations') = 0)::integer
      SQL
    )
  end

  DEFAULT_COUNTS_BY_STATUS = STATUSES.map(&:to_s).product([0]).to_h
  def self.counts_by_status(relation)
    DEFAULT_COUNTS_BY_STATUS.merge(relation.group(:status).count)
  end

  # @param query [ActiveRecord::Relation] the current HarvestItem query
  # @param path [String] the path to filter by
  # @return [Array<Hash>]
  def self.project_directory_listing(query, path)
    path = path.trim('/')
    path += '/' unless path.blank?

    slash_count = path.count('/')
    dir_path = 'dir_path'

    table = HarvestItem.arel_table
    path_col = table[:path]

    dir_count = \
      query
      # match 'directories' only in current 'directory' -
      # that is there is at least two more slashes after our prefix path
      # e.g. {path}/dir/file.ext
      .where(path_col =~ "^#{path}[^/]+/.+$")
      .order(path_col.asc)
      # transform path into only those immediate sub-directories of our prefix path
      .select(
        Arel.sql(
          "array_to_string((string_to_array(path, '/'))[1:#{slash_count + 1}],'/')"
        ).as(dir_path),
        'harvest_id as harvest_id_unambiguous'
      )

    HarvestItem
      .from(dir_count, 'dir_subquery')
      # group by the immediate directories in the path
      .group(dir_path)
      .select(
        Arel.sql("MAX(#{dir_path})").as(path_col.name),
        Arel.sql('MAX(dir_subquery.harvest_id_unambiguous)').as('harvest_id')
      )
  end

  # When we return fake harvest items that are directories, the id is nil
  def pseudo_directory?
    id.nil?
  end

  # @param query [ActiveRecord::Relation] the current HarvestItem query
  # @param path [String] the path to filter by
  # @return [ActiveRecord::Relation]
  def self.project_file_listing(query, path)
    path = path.trim('/')
    path += '/' unless path.blank?

    table = HarvestItem.arel_table
    path_col = table[:path]

    query
      # match files only in current 'directory' - that is the path is the
      # whole prefix before the last '/'
      .where(path_col =~ "^#{path}[^/]+$")
      .order(path: :asc)
  end

  def self.filter_settings
    filterable_fields = [
      :id, :deleted, :path, :status, :created_at,
      :updated_at, :audio_recording_id, :uploader_id
    ]
    {
      valid_fields: [*filterable_fields],
      render_fields: [
        *filterable_fields,
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
          query_attributes: [:path, :harvest_id],
          transform: ->(item) { item.path_relative_to_harvest },
          arel: nil,
          type: :string
        }
      },
      new_spec_fields: ->(_user) { {} },
      controller: :harvest_items,
      action: :filter,
      defaults: {
        order_by: :id,
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

  def self.schema
    {
      type: :object,
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        deleted: { type: 'boolean', readOnly: true },
        path: { type: 'string', readOnly: true },
        status: { type: 'string', enum: STATUSES, readOnly: true },
        created_at: Api::Schema.date(read_only: true),
        updated_at: Api::Schema.date(read_only: true),
        audio_recording_id: Api::Schema.id(nullable: true),
        uploader_id: Api::Schema.id(nullable: true),
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
        }
      }
    }
  end

  def self.directory_schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        path: { type: 'string', readOnly: true },
        id: { type: 'null', readOnly: true }
      }
    }
  end

  def self.directory_list_schema
    {
      type: 'array',
      readOnly: true,
      items: {
        oneOf: [
          HarvestItem.schema,
          HarvestItem.directory_schema

        ]
      }
    }
  end
end
