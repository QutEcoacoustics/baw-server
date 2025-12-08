# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id                      :integer          not null, primary key
#  allow_audio_upload      :boolean          default(FALSE)
#  allow_original_download :string
#  deleted_at              :datetime
#  description             :text
#  image_content_type      :string
#  image_file_name         :string
#  image_file_size         :bigint
#  image_updated_at        :datetime
#  license                 :text
#  name                    :string           not null
#  notes                   :text
#  urn                     :string
#  created_at              :datetime
#  updated_at              :datetime
#  creator_id              :integer          not null
#  deleter_id              :integer
#  updater_id              :integer
#
# Indexes
#
#  index_projects_on_creator_id  (creator_id)
#  index_projects_on_deleter_id  (deleter_id)
#  index_projects_on_updater_id  (updater_id)
#  projects_name_uidx            (name) UNIQUE
#
# Foreign Keys
#
#  projects_creator_id_fk  (creator_id => users.id)
#  projects_deleter_id_fk  (deleter_id => users.id)
#  projects_updater_id_fk  (updater_id => users.id)
#
class Project < ApplicationRecord
  extend Enumerize

  # relationships
  belongs_to :creator, class_name: 'User', inverse_of: :created_projects
  belongs_to :updater, class_name: 'User', inverse_of: :updated_projects, optional: true
  belongs_to :deleter, class_name: 'User', inverse_of: :deleted_projects, optional: true

  has_many :permissions, inverse_of: :project, dependent: :destroy
  # remove joins clause in next major rails version. See https://github.com/rails/rails/pull/39390/files
  has_many :readers, lambda {
                       joins(:permissions).where({ permissions: { level: 'reader' } }).distinct
                     }, through: :permissions, source: :user
  has_many :writers, lambda {
                       joins(:permissions).where({ permissions: { level: 'writer' } }).distinct
                     }, through: :permissions, source: :user
  has_many :owners, lambda {
                      joins(:permissions).where({ permissions: { level: 'owner' } }).distinct
                    }, through: :permissions, source: :user

  has_many :projects_sites, inverse_of: :project, dependent: :destroy
  has_many :sites, -> { distinct }, through: :projects_sites

  has_many :regions, inverse_of: :project
  has_many :harvests, inverse_of: :project

  has_many :projects_saved_searches, inverse_of: :project
  has_many :saved_searches, through: :projects_saved_searches
  has_many :analysis_jobs, inverse_of: :project

  accepts_nested_attributes_for :permissions

  # plugins
  has_attached_file :image,
    styles: { span4: '300x300#', span3: '220x220#', span2: '140x140#', span1: '60x60#', spanhalf: '30x30#' },
    default_url: '/images/project/project_:style.png'

  # add deleted_at and deleter_id
  acts_as_discardable
  also_discards :regions, :analysis_jobs

  # association validations
  #validates_associated :creator

  # attribute validations
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  #validates :urn, uniqueness: {case_sensitive: false}, allow_blank: true, allow_nil: true
  validates :urn, format: { with: %r{\Aurn:[a-z0-9][a-z0-9-]{0,31}:[a-z0-9()+,\-.:=@;$_!*'%/?#]+\z},
                            message: 'urn %<value>s is not valid, must be in format urn:<name>:<path>', allow_blank: true }
  validates_attachment_content_type :image, content_type: %r{\Aimage/(jpg|jpeg|pjpeg|png|x-png|gif)\z},
    message: 'file type %<value>s is not allowed (only jpeg/png/gif images)'

  validates :license, length: { minimum: 1 }, allow_nil: true

  # ensure allow original download is a permission level.
  # Do not add predicates to Project ( #reader?, #writer?, #owner? do not make sense when attached directly to Project).
  enumerize :allow_original_download, in: Permission::AVAILABLE_LEVELS, default: nil, predicates: false

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
                     :deleted_at,
                     :license,
                     # This field is intentionally excluded from the render_fields so that it is not emitted by default
                     # and needs to be explicitly included using filter projection.
                     # I don't include this field by default because it introduces a joins on the site and
                     # audio_recordings table which can slow down queries when it is not needed.
                     :has_audio],
      render_fields: [:id, :name, :description, :creator_id,
                      :created_at,
                      :updater_id,
                      :updated_at,
                      :deleter_id,
                      :deleted_at,
                      :notes,
                      :allow_original_download,
                      :allow_audio_upload,
                      :license],
      text_fields: [:name, :description],
      custom_fields: lambda { |item, user|
                       # do a query for the attributes that may not be in the projection
                       # instance or id can be nil
                       fresh_project = item.nil? || item.id.nil? ? nil : Project.find(item.id)

                       project_hash = {}
                       project_hash[:site_ids] = fresh_project.nil? ? nil : fresh_project.sites.pluck(:id).flatten
                       project_hash[:region_ids] = fresh_project.nil? ? nil : fresh_project.regions.pluck(:id).flatten
                       project_hash[:owner_ids] = fresh_project.nil? ? nil : fresh_project.owners.pluck(:id).flatten
                       project_hash[:image_urls] = Api::Image.image_urls(fresh_project.image)
                       project_hash.merge!(item.render_markdown_for_api_for(:description))

                       # access level for the current user - useful for showing users what their current permission level is
                       project_hash[:access_level] = Project.access_level(item, user)
                       [item, project_hash]
                     },
      custom_fields2: {
        has_audio: {
          query_attributes: [],
          transform: nil,
          arel: Project.has_audio_arel?,
          type: :boolean
        }
      },
      new_spec_fields: lambda { |_user|
                         {
                           name: nil,
                           description: nil,
                           allow_original_download: nil,
                           notes: nil
                         }
                       },
      controller: :projects,
      action: :filter,
      defaults: {
        order_by: :name,
        direction: :asc
      },
      capabilities: {
        update_allow_audio_upload:
        {
          can_item: ->(item) { Current.ability.can?(:allow_audio_upload, item) },
          details: nil
        },
        create_harvest: {
          can_item: ->(item) { Current.ability.can?(:create, Harvest.new(project: item)) && item&.allow_audio_upload },
          details: lambda { |can, item, _klass|
                     unless can
                       if item&.allow_audio_upload
                         'You do not have permission to upload audio. You must be an owner of this project.'
                       else
                         'This project does not allow uploading audio. Contact the site administrator to request permission to upload audio.'
                       end
                     end
                   }
        }
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
        id: Api::Schema.id,
        name: { type: 'string' },
        **Api::Schema.rendered_markdown(:description),
        #notes: { type: 'object' }, # TODO: https://github.com/QutEcoacoustics/baw-server/issues/467
        notes: { type: 'string' },
        **Api::Schema.all_user_stamps,
        site_ids: Api::Schema.ids(read_only: true),
        region_ids: Api::Schema.ids(read_only: true),
        owner_ids: Api::Schema.ids(read_only: true),
        image_urls: Api::Schema.image_urls,
        access_level: Api::Schema.permission_levels,
        allow_original_download: Api::Schema.permission_levels,
        allow_audio_upload: { type: 'boolean' },
        license: { type: ['string', 'null'] },
        has_audio: { type: 'boolean', readOnly: true }
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
        :region_ids,
        :image_urls,
        :allow_original_download,
        :license
      ]
    }.freeze
  end

  def self.access_level(project, user)
    levels = Access::Core.user_levels(user, project)
    Access::Core.highest(levels)
  end

  # @return [Boolean]
  def self.has_audio_arel?
    audio_recordings_table = AudioRecording.arel_table
    project_table = Project.arel_table
    site_table = Site.arel_table

    # A temporary (currently empty) table for the join between the sites and project tables.
    projects_sites_table = Arel::Table.new(:projects_sites)

    # We reduce the number of fields returned to just the id so that there is less data to process.
    # Additionally, we use a select + limit query instead of using a count query so that the database can stop querying
    # as soon as it finds one matching record instead of having to count all matching records.
    query = audio_recordings_table
      .project(audio_recordings_table[:id])
      .join(site_table).on(audio_recordings_table[:site_id].eq(site_table[:id]))
      .join(projects_sites_table).on(site_table[:id].eq(projects_sites_table[:site_id]))
      .where(projects_sites_table[:project_id].eq(project_table[:id]))
      .take(1)

    Arel::Nodes::Exists.new(query)
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
