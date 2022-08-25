# frozen_string_literal: true

# == Schema Information
#
# Table name: regions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  name        :string
#  notes       :jsonb
#  created_at  :datetime
#  updated_at  :datetime
#  creator_id  :integer
#  deleter_id  :integer
#  project_id  :integer          not null
#  updater_id  :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
class Region < ApplicationRecord
  # relations
  has_many :sites, inverse_of: :region

  belongs_to :project, inverse_of: :regions
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_regions
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_regions, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_regions, optional: true

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # add model image
  has_one_attached :image
  # Named variants not available until rails 7
  #has_one_attached :image do |attachable|
  #attachable.variant :thumb, resize: "#{BawApp.attachment_thumb_size}"
  #end

  # attribute validations
  validates :name, presence: true, length: { minimum: 2 }

  validates :image,
    size: {
      less_than_or_equal_to: BawApp.attachment_size_limit,
      message: "%<attribute>s size %<file_size>s is greater than #{ActiveSupport::NumberHelper.number_to_human_size(BawApp.attachment_size_limit)}, try a smaller file"
    },
    content_type: [:png, :jpg, :jpeg]

  def self.filter_settings
    common_fields = [:id, :name, :description, :notes, :creator_id, :created_at, :updater_id, :updated_at, :deleter_id,
                     :deleted_at, :project_id]
    {
      valid_fields: common_fields,
      render_fields: common_fields,
      text_fields: [:name, :description],
      custom_fields: lambda { |item, _user|
        extra_fields = {
          site_ids: item.sites.pluck(:id).flatten,
          **item.render_markdown_for_api_for(:description),
          image_urls: Api::Image.image_urls(item.image)
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
        site_ids: { type: 'array', items: { '$ref' => '#/components/schemas/id' }, readOnly: true },
        image_urls: Api::Schema.image_urls,
        image: { type: 'string', format: 'binary', writeOnly: true, nullable: true }
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
        :site_ids,
        :image_urls
      ]
    }.freeze
  end
end
