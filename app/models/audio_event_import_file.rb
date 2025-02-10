# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_import_files
#
#  id                                                                                             :bigint           not null, primary key
#  additional_tag_ids(Additional tag ids applied for this import)                                 :integer          is an Array
#  file_hash(Hash of the file contents used for uniqueness checking)                              :text
#  path(Path to the file on disk, relative to the analysis job item. Not used for uploaded files) :string
#  created_at                                                                                     :datetime         not null
#  analysis_jobs_item_id                                                                          :integer
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

  # hooks

  before_validation :generate_hash

  # attributes

  def additional_tag_ids=(value)
    super(value&.map { |x| x.try(:to_i) }&.reject(&:blank?)&.reject(&:zero?))
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

  # validations
  validates :file_hash, presence: true
  validate :validate_path_exists, if: -> { path.present? }
  validate :validate_analysis_association_and_path_or_file
  validate :validate_path_xor_attachment
  validate :tags_exist
  validate :attachment_acceptable, if: -> { file.attached? }
  validate :attachment_unique, if: -> { file.attached? }
  validate :attachment_size, if: -> { file.attached? }

  def self.filter_settings
    common_fields = [
      :id, :additional_tag_ids, :path, :name, :audio_event_import_id, :analysis_jobs_item_id,
      :created_at, :file_hash
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
          query_attributes: [:path],
          transform: lambda { |item|
            item.path.nil? ? item.file.filename : File.basename(item.path)
          },
          type: :string,
          arel: nil
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           additional_tags: [],
                           file: nil,
                           audio_event_import_id: nil
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
        analysis_jobs_item_id: Api::Schema.id(nullable: true, read_only: true)

      },
      required: [
        :id,
        :additional_tag_ids,
        :file_hash,
        :path,
        :name,
        :created_at,
        :audio_event_import_id,
        :analysis_jobs_item_id
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
                          }
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
