# frozen_string_literal: true

class Project < ApplicationRecord
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_projects
  belongs_to :updater, class_name: 'User', foreign_key: :updater_id, inverse_of: :updated_projects, optional: true
  belongs_to :deleter, class_name: 'User', foreign_key: :deleter_id, inverse_of: :deleted_projects, optional: true

  has_many :permissions, inverse_of: :project
  # remove joins clause in next major rails version. See https://github.com/rails/rails/pull/39390/files
  has_many :readers, -> { joins(:permissions).where({ permissions: { level: 'reader' } }).distinct }, through: :permissions, source: :user
  has_many :writers, -> { joins(:permissions).where({ permissions: { level: 'writer' } }).distinct }, through: :permissions, source: :user
  has_many :owners, -> { joins(:permissions).where({ permissions: { level: 'owner' } }).distinct }, through: :permissions, source: :user
  has_and_belongs_to_many :sites, -> { distinct }
  has_and_belongs_to_many :saved_searches, inverse_of: :projects
  has_many :analysis_jobs, through: :saved_searches

  accepts_nested_attributes_for :permissions

  #plugins
  has_attached_file :image,
                    styles: { span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#' },
                    default_url: '/images/project/project_:style.png'

  # add deleted_at and deleter_id
  acts_as_paranoid
  validates_as_paranoid

  # association validations
  validates_associated :creator

  # attribute validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  #validates :urn, uniqueness: {case_sensitive: false}, allow_blank: true, allow_nil: true
  validates_format_of :urn, with: %r{\Aurn:[a-z0-9][a-z0-9-]{0,31}:[a-z0-9()+,\-.:=@;$_!*'%/?#]+\z}, message: 'urn %{value} is not valid, must be in format urn:<name>:<path>', allow_blank: true, allow_nil: true
  validates_attachment_content_type :image, content_type: %r{\Aimage/(jpg|jpeg|pjpeg|png|x-png|gif)\z}, message: 'file type %{value} is not allowed (only jpeg/png/gif images)'

  # make sure the project has a permission entry for the creator after it is created
  after_create :create_owner_permission

  renders_markdown_for :description

  # Define filter api settings
  def self.filter_settings
    {
      valid_fields: [:id, :name, :description, :creator_id,
                     :created_at,
                     :updater_id,
                     :updated_at,
                     :deleter_id,
                     :deleted_at],
      render_fields: [:id, :name, :description, :creator_id,
                      :created_at,
                      :updater_id,
                      :updated_at,
                      :deleter_id,
                      :deleted_at, :notes],
      text_fields: [:name, :description],
      custom_fields: lambda { |item, _user|
                       # do a query for the attributes that may not be in the projection
                       # instance or id can be nil
                       fresh_project = item.nil? || item.id.nil? ? nil : Project.find(item.id)

                       project_hash = {}
                       project_hash[:site_ids] = fresh_project.nil? ? nil : fresh_project.sites.pluck(:id).flatten
                       project_hash[:owner_ids] = fresh_project.nil? ? nil : fresh_project.owners.pluck(:id).flatten
                       project_hash[:image_urls] = Api::Image.image_urls(fresh_project.image)
                       project_hash.merge!(item.render_markdown_for_api_for(:description))

                       [item, project_hash]
                     },
      controller: :projects,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      },
      valid_associations: [
        {
          join: Permission,
          on: Permission.arel_table[:project_id].eq(Project.arel_table[:id]),
          available: true
        },
        {
          join: Arel::Table.new(:projects_sites),
          on: Project.arel_table[:id].eq(Arel::Table.new(:projects_sites)[:project_id]),
          available: false,
          associations: [
            {
              join: Site,
              on: Arel::Table.new(:projects_sites)[:site_id].eq(Site.arel_table[:id]),
              available: true
            }
          ]

        },
        {
          join: Arel::Table.new(:projects_saved_searches),
          on: Project.arel_table[:id].eq(Arel::Table.new(:projects_saved_searches)[:project_id]),
          available: false,
          associations: [
            {
              join: SavedSearch,
              on: Arel::Table.new(:projects_saved_searches)[:saved_search_id].eq(SavedSearch.arel_table[:id]),
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
        id: { '$ref' => '#/components/schemas/id', readOnly: true },
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        #notes: { type: 'object' }, # TODO: https://github.com/QutEcoacoustics/baw-server/issues/467
        notes: { type: 'string' },
        **Api::Schema.all_ids_and_ats,
        site_ids: { type: 'array', items: { '$ref' => '#/components/schemas/id' } },
        owner_ids: { type: 'array', items: { '$ref' => '#/components/schemas/id' }, readOnly: true },
        image_urls: Api::Schema.image_urls
      },
      required: [
        :id,
        :name,
        :description,
        :description_html,
        :description_html_tagline,
        :notes,
        :creator_id,
        :created_at,
        :updater_id,
        :updated_at,
        :deleter_id,
        :deleted_at,
        :owner_ids,
        :site_ids,
        :image_urls
      ]
    }.freeze
  end

  private

  def create_owner_permission
    the_user = creator
    the_admin = User.where(roles_mask: 1).first!
    Permission.find_or_create_by(
      level: 'owner',
      user: the_user,
      project: self,
      creator: the_admin,
      allow_logged_in: false,
      allow_anonymous: false
    )
  end
end
