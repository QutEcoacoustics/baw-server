# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_imports
#
#  id                                                     :bigint           not null, primary key
#  deleted_at                                             :datetime
#  description                                            :text
#  name                                                   :string
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#  analysis_job_id(Analysis job that created this import) :integer
#  creator_id                                             :integer          not null
#  deleter_id                                             :integer
#  updater_id                                             :integer
#
# Indexes
#
#  index_audio_event_imports_on_analysis_job_id  (analysis_job_id)
#
# Foreign Keys
#
#  audio_event_imports_creator_id_fk  (creator_id => users.id)
#  audio_event_imports_deleter_id_fk  (deleter_id => users.id)
#  audio_event_imports_updater_id_fk  (updater_id => users.id)
#  fk_rails_...                       (analysis_job_id => analysis_jobs.id)
#
class AudioEventImport < ApplicationRecord
  # associations
  has_many :audio_event_import_files, inverse_of: :audio_event_import, dependent: :destroy
  has_many :audio_events, through: :audio_event_import_files

  belongs_to :analysis_job, inverse_of: :audio_event_imports, optional: true

  belongs_to :creator, class_name: 'User', inverse_of: :created_audio_event_imports
  belongs_to :updater, class_name: 'User', inverse_of: :updated_audio_event_imports, optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_audio_event_imports, optional: true

  # scopes
  # @!method self.created_by(user)
  #   Finds records created by given user
  #   @param user [User] User to filter by
  #   @return [::ActiveRecord::Relation]
  scope :created_by, ->(user) { AudioEventImport.where(creator: user) }

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :audio_events, batch: true

  # validations
  validates :name, presence: true, length: { minimum: 2 }

  def self.filter_settings
    common_fields = [
      :id, :name, :description, :analysis_job_id,
      :creator_id, :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at
    ]
    {
      valid_fields: common_fields,
      render_fields: common_fields + [:description_html_tagline, :description_html],
      text_fields: [:name, :description],
      custom_fields2: {
        **AudioEventImport.new_render_markdown_for_api_for(:description)
      },
      new_spec_fields: lambda { |_user|
        {
          name: nil,
          description: nil,
          analysis_jobs_id: nil
        }
      },
      controller: :audio_event_imports,
      action: :filter,
      defaults: {
        order_by: :created_at,
        direction: :asc
      },
      valid_associations: [
        {
          join: AnalysisJob,
          on: AudioEventImport.arel_table[:analysis_jobs_id].eq(AnalysisJob.arel_table[:id]),
          available: true
        },
        {
          join: AudioEventImportFile,
          on: AudioEventImport.arel_table[:id].eq(AudioEventImportFile.arel_table[:audio_event_import_id]),
          available: true,
          associations: [
            {
              join: AudioEvent,
              on: AudioEventImportFile.arel_table[:id].eq(AudioEvent.arel_table[:audio_event_import_file_id]),
              available: true
            }
          ]
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
        analysis_job_id: Api::Schema.id(nullable: true, read_only: true),
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.all_user_stamps
      },
      required: [
        :id,
        :name,
        :description,
        :description_html,
        :description_html_tagline,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at
      ]
    }.freeze
  end
end
