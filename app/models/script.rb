class Script < ActiveRecord::Base
  # ensures that creator_id, updater_id, deleter_id are set
  include UserChange

  # relationships
  belongs_to :creator, class_name: 'User', foreign_key: :creator_id, inverse_of: :created_scripts
  has_many :analysis_jobs, inverse_of: :script

  # association validations
  validates :creator, existence: true

  # attribute validations
  validates :name, :analysis_identifier, :executable_command, :executable_settings, :executable_settings_media_type, presence: true, length: {minimum: 2}
  validate :check_version_increase, on: :create

  # for the first script in a group, make sure group_id is set to the script's id
  after_create :set_group_id, :set_versions

  def display_name
    "#{self.name} - v. #{self.version}"
  end

  def latest_version
    Script
        .where(group_id: self.group_id)
        .order(version: :desc)
        .first
  end

  def earliest_version
    Script
        .where(group_id: self.group_id)
        .order(version: :asc)
        .first
  end

  def last_version
    self.read_attribute(:last_version)
  end

  def is_last_version?
    self.version == self.last_version
  end

  def first_version
    self.read_attribute(:first_version)
  end

  def is_first_version?
    self.version == self.first_version
  end

  # override the default query for the model
  def self.default_scope
    query = <<-SQL
    INNER JOIN (
      SELECT "group_id", max("version") AS "last_version", min("version") AS "first_version"
      FROM "scripts"
      GROUP BY "group_id"
    ) s2 on ("scripts"."group_id" = "s2"."group_id")
    SQL

    joins(query).select('"scripts".*, "s2"."last_version", "s2"."first_version"')
  end

  # a fake reference to the aliased table defined in the default scope
  @script_group = Arel::Table.new('s2', @arel_engine)

  # HACK: reload item - this is a poor version of Persistence::reload
  # https://github.com/rails/rails/blob/1f98eb60e59f4f70ef66ac2454ad029f46e3b27c/activerecord/lib/active_record/persistence.rb#L432
  # The only difference is the `unscoped` method is removed.
  def reload(options = nil)
    self.class.connection.clear_query_cache

    fresh_object =
        if options && options[:lock]
          self.class.lock(options[:lock]).find(id)
        else
          self.class.find(id)
        end

    @attributes = fresh_object.instance_variable_get('@attributes')
    @new_record = false
    self
  end

  def all_versions
    Script.where(group_id: self.group_id).order(created_at: :desc)
  end

  def self.filter_settings
    {
        valid_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings_media_type,
                       :version, :created_at, :creator_id, :is_last_version, :is_first_version],
        render_fields: [:id, :group_id, :name, :description, :analysis_identifier, :executable_settings,
                        :executable_settings_media_type, :version, :created_at, :creator_id],
        text_fields: [:name, :description, :analysis_identifier, :executable_settings_media_type],
        custom_fields: lambda { |item, user|
          virtual_fields = {
              is_last_version: item.is_last_version?,
              is_first_version: item.is_first_version?
          }
          [item, virtual_fields]
        },
        field_mappings: [
            {
                name: :is_last_version,
                value: Arel::Nodes::Grouping.new(
                    Arel::Nodes::InfixOperation.new(
                        '='.to_sym,
                        @script_group[:last_version],
                        Script.arel_table[:version]
                    )
                )
            },
            {
                name: :is_first_version,
                value: Arel::Nodes::Grouping.new(
                    Arel::Nodes::InfixOperation.new(
                        '='.to_sym,
                        @script_group[:first_version],
                        Script.arel_table[:version]
                    )
                )
            }
        ],
        controller: :scripts,
        action: :filter,
        defaults: {
            order_by: :name,
            direction: :asc
        }
    }
  end

  private

  def check_version_increase
    matching_or_higher_versions =
        Script
            .unscoped
            .where(group_id: self.group_id)
            .where('version >= ?', self.version)
    if matching_or_higher_versions.count > 0
      errors.add(:version, "must be higher than previous versions (#{matching_or_higher_versions.pluck(:version).flatten.join(', ')})")
    end
  end

  def set_group_id
    if self.group_id.blank?
      self.group_id = self.id
      self.save!
    end

  end

  # this is needed because the default scope query is not run when creating
  # should only be called :after_create
  def set_versions
    # HACK: another select has to be run
    self.reload
  end

end
