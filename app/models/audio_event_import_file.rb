# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_import_files
#
#  id                                                                                             :bigint           not null, primary key
#  additional_tag_ids(Additional tag ids applied for this import)                                 :integer          is an Array
#  file_hash(Hash of the file contents used for uniqueness checking)                              :text
#  imported_count(Number of events parsed minus rejections)                                       :integer          default(0), not null
#  include_top(Limit import to the top N results per tag per file)                                :integer
#  include_top_per(Apply top filtering per this interval, in seconds)                             :integer
#  minimum_score(Minimum score threshold actually used)                                           :decimal(, )
#  parsed_count(Number of events parsed from this file)                                           :integer          default(0), not null
#  path(Path to the file on disk, relative to the analysis job item. Not used for uploaded files) :string
#  created_at                                                                                     :datetime         not null
#  analysis_jobs_item_id                                                                          :bigint
#  audio_event_import_id                                                                          :integer          not null
#
# Indexes
#
#  index_audio_event_import_files_on_analysis_jobs_item_id  (analysis_jobs_item_id)
#  index_audio_event_import_files_on_audio_event_import_id  (audio_event_import_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_jobs_item_id => analysis_jobs_items.id) ON DELETE => cascade
#  fk_rails_...  (audio_event_import_id => audio_event_imports.id) ON DELETE => cascade
#
class AudioEventImportFile < ApplicationRecord
  # associations
  has_many :audio_events, lambda {
    includes [:taggings, :verifications]
  }, inverse_of: :audio_event_import_file, dependent: :destroy

  belongs_to :audio_event_import, inverse_of: :audio_event_import_files
  belongs_to :analysis_jobs_item, inverse_of: :audio_event_import_files, optional: true

  has_one_attached :file

  # returns the filename of either an uploaded file or result from an analysis job.
  # Make sure you're joining on blobs if you want to use this in a query.
  # `AudioEventImportFile.left_outer_joins(:file_blob)`
  def self.name_arel
    Arel::Nodes::NamedFunction.new('basename', [arel_table[:path]])
      .coalesce(ActiveStorage::Blob.arel_table[:filename])
  end

  # hooks

  before_validation :generate_hash

  # attributes

  def additional_tag_ids=(value)
    raise ArgumentError, 'additional_tag_ids must be an array' unless value.is_a?(Array)
    raise ArgumentError, 'additional_tag_ids must be an array of integers' unless value.all? { |v| v.is_a?(Integer) }

    super
  end

  def additional_tags
    @additional_tags ||= Tag.where(id: additional_tag_ids)
  end

  # @return [Pathname]
  def absolute_path
    base = analysis_jobs_item&.results_absolute_path

    return nil if base.nil? || path.nil?

    base / path
  end

  def name
    file.attached? ? file.filename : File.basename(path)
  end

  # validations
  validates :file_hash, presence: true
  validates :minimum_score, allow_nil: true, numericality: true
  validates :include_top, allow_nil: true, numericality: { only_integer: true, greater_than: 0 }
  validates :include_top_per, allow_nil: true, numericality: { only_integer: true, greater_than: 0 }
  validate :validate_path_exists, if: -> { path.present? }
  validate :validate_analysis_association_and_path_or_file
  validate :validate_path_xor_attachment
  validate :tags_exist
  validate :top_filtering_consistent
  validate :attachment_acceptable, if: -> { file.attached? }
  validate :attachment_unique, if: -> { file.attached? }
  validate :attachment_size, if: -> { file.attached? }

  def self.filter_settings
    common_fields = [
      :id, :additional_tag_ids, :path, :name, :audio_event_import_id, :analysis_jobs_item_id,
      :created_at, :file_hash, :minimum_score, :imported_count, :parsed_count, :include_top, :include_top_per
    ]
    {
      valid_fields: common_fields,
      render_fields: common_fields,

      text_fields: [:name],
      custom_fields2: {
        path: {
          query_attributes: [:path],
          transform: lambda { |item|
            next nil if item.id.nil?

            item.path.nil? ? item.file.url : item.path
          },
          type: :string,
          arel: nil
        },
        name: {
          id: 'name',
          query_attributes: [],
          transform: lambda { |item|
            next item[:name] if item[:name].present?

            item.path.nil? ? item.file.filename : File.basename(item.path)
          },
          type: :string,
          arel: name_arel,
          joins: AudioEventImportFile.left_outer_joins(:file_blob).arel.join_sources
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           additional_tags: [],
                           file: nil,
                           audio_event_import_id: nil,
                           minimum_score: nil,
                           include_top: nil,
                           include_top_per: nil
                         }
                       },
      controller: :audio_event_import_files,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :asc
      },
      valid_associations: [
        {
          join: AudioEventImport,
          on: AudioEventImport.arel_table[:id].eq(AudioEventImportFile.arel_table[:audio_event_import_id]),
          available: true,
          associations: [
            {
              join: AnalysisJob,
              on: AnalysisJob.arel_table[:id].eq(AudioEventImport.arel_table[:analysis_job_id]),
              available: true
            }
          ]
        },
        {
          join: AnalysisJobsItem,
          on: AnalysisJobsItem.arel_table[:id].eq(AudioEventImportFile.arel_table[:analysis_jobs_item_id]),
          available: true,
          associations: [
            {
              join: AnalysisJob,
              on: AnalysisJob.arel_table[:id].eq(AnalysisJobsItem.arel_table[:analysis_job_id]),
              available: true
            },
            {
              join: Script,
              on: Script.arel_table[:id].eq(AnalysisJobsItem.arel_table[:script_id]),
              available: true
            }
          ]
        },
        {
          join: AudioEvent,
          on: AudioEvent.arel_table[:audio_event_import_file_id].eq(AudioEventImportFile.arel_table[:id]),
          available: true
        }
      ]
    }
  end

  def self.schema
    {
      type: 'object',
      additionalProperties: false,
      properties: {
        id: Api::Schema.id,
        additional_tag_ids: Api::Schema.ids(nullable: true, read_only: true),
        file_hash: { type: 'string', readOnly: true },
        path: { type: ['null', 'string'], readOnly: true },
        name: { type: 'string', readOnly: true },
        created_at: Api::Schema.date(read_only: true),
        audio_event_import_id: Api::Schema.id(read_only: true),
        analysis_jobs_item_id: Api::Schema.id(nullable: true, read_only: true),
        minimum_score: { type: ['null', 'number'], readOnly: true },
        imported_count: { type: 'integer', readOnly: true },
        parsed_count: { type: 'integer', readOnly: true },
        include_top: { type: ['null', 'integer'], readOnly: true },
        include_top_per: { type: ['null', 'integer'], readOnly: true }
      },
      required: [
        :id,
        :additional_tag_ids,
        :file_hash,
        :path,
        :name,
        :created_at,
        :audio_event_import_id,
        :analysis_jobs_item_id,
        :minimum_score,
        :include_top,
        :include_top_per
      ]
    }
  end

  def self.create_schema
    {
      type: 'object',
      properties: {
        allOf: [
          { '$ref' => '#/components/schemas/audio_event_import_file' },
          {
            type: 'object',
            properties: {
              imported_events: {
                type: 'array',
                items: {
                  allOf: [
                    { '$ref' => '#/components/schemas/audio_event' },
                    {
                      type: 'object',
                      properties: {
                        tags: {
                          type: 'array',
                          items: {
                            properties: {
                              id: Api::Schema.id(nullable: true),
                              name: { type: 'string' }
                            },
                            required: [:id, :text]
                          }
                        }
                      }
                    },
                    {
                      type: 'object',
                      properties: {
                        errors: {
                          type: 'array',
                          items: {
                            type: 'object'
                          },
                          description: 'A detailed list of validation errors that stopped this event being imported, and caused a failure'
                        },
                        rejections: {
                          type: 'array',
                          items: {
                            type: 'object'
                          },
                          description: 'A detailed list of reasons why this event was not imported'
                        }
                      }
                    }
                  ]
                },
                readOnly: true
              },
              committed: { type: 'boolean', readOnly: true }
            },

            required: [
              :imported_events,
              :committed
            ]
          }

        ]
      }
    }
  end

  private

  # helpers

  def generate_hash
    if absolute_path&.exist?
      self.file_hash = (Digest::SHA512.file(absolute_path).hexdigest if absolute_path.exist?)
    end

    return unless file.attached?

    # We only generate a hash on creation, before saving
    # This means file.blob.download, apart from being inefficient because it will copy the file,
    # will also not work as the file is not yet saved.
    # So we look at the changeset and pull out the uploaded file instance
    # and generate the hash from that.
    tempfile = attachment_changes['file']&.attachable&.tempfile

    # this is bad, but our validations should catch it
    return if tempfile.nil?

    self.file_hash = (Digest::SHA512.file(tempfile).hexdigest if file.attached?)
  end

  def validate_path_exists
    return if absolute_path&.exist?

    errors.add(:path, 'does not exist')
  end

  def validate_analysis_association_and_path_or_file
    case [path.present?, analysis_jobs_item_id.present?]
    in [true, false]
      errors.add(:base, 'Path requires an analysis_jobs_item association')
    in [false, true]
      errors.add(:base, 'analysis_jobs_item association requires a path')
    else
      # valid
    end
  end

  def validate_path_xor_attachment
    case [path.present?, file.attached?]
    in [true, true]
      errors.add(:base, 'Specify either a path or a file, not both')
    in [false, false]
      errors.add(:base, 'Either a path or a file must be specified')
    else
      # valid
    end
  end

  def tags_exist
    return if additional_tag_ids.blank?

    errors.add(:additional_tag_ids, 'contains invalid tag ids') unless additional_tags.count == additional_tag_ids.count
  end

  def top_filtering_consistent
    # include_top_per depends on include_top, but include_top can work alone
    return if include_top_per.nil? || include_top.present?

    errors.add(:include_top_per, 'can only be set when include_top is also set')
  end

  def attachment_acceptable
    return if file.content_type.in?(Settings.supported_audio_event_import_file_media_types)

    errors.add(:file, 'is not an acceptable content type')
  end

  def attachment_unique
    # we have much more control over imports from analysis jobs
    # so we can be more relaxed about uniqueness, especially as we have,
    # ironically, less control over the file contents.
    #
    # We still calculate a hash though
    return if analysis_jobs_item_id.present?

    # should be set when `file` is attached
    raise 'Cannot validate uniqueness without a hash' if file_hash.blank?

    existing = AudioEventImportFile
      .where
      .not(id:)
      .find_by(file_hash:)

    return if existing.nil?

    errors.add(:file, "is not unique. Duplicate record found with id: #{existing.id}")
  end

  def attachment_size
    return if file.byte_size <= Settings.audio_event_imports.max_file_size_bytes

    errors.add(:file,
      "is too large, must be less than #{ActiveSupport::NumberHelper.number_to_human_size(Settings.audio_event_imports.max_file_size_bytes)}")
  end
end
