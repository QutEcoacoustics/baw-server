# frozen_string_literal: true

class Region < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relations
  has_many :sites, inverse_of: :region

  belongs_to :project, inverse_of: :regions
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_regions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_regions, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_regions, optional: true

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # attribute validations
  validates :name, presence: true, length: { minimum: 2 }

  def self.filter_settings
    common_fields = [:id, :name, :description, :notes, :creator_id, :created_at, :updater_id, :updated_at, :deleter_id, :deleted_at, :project_id]
    {
      valid_fields: common_fields,
      render_fields: common_fields,
      text_fields: [:name, :description],
      custom_fields: lambda { |item, _user|
        extra_fields = {
          site_ids: item.sites.pluck(:id).flatten,
          **item.render_markdown_for_api_for(:description)
        }
        [item, extra_fields]
      },
      new_spec_fields: lambda { |_user|
        {
          name: nil,
          description: nil,
          notes: nil,
          project_id: nil
        }
      },
      controller: :regions,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      },
      valid_associations: [
        {
          join: Project,
          on: Region.arel_table[:project_id].eq(Project.arel_table[:id]),
          available: true
        },
        {
          join: Site,
          on: Region.arel_table[:id].eq(Site.arel_table[:id]),
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
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        **Api::Schema.all_user_stamps,
        notes: { type: 'object' },
        project_id: { '$ref' => '#/components/schemas/id' },
        site_ids: { type: 'array', items: { '$ref' => '#/components/schemas/id' } }
      },
      required: [
        :id,
        :name,
        :notes,
        :project_id,
        :description,
        :description_html,
        :description_html_tagline,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at,
        :site_ids
      ]
    }.freeze
  end
end
