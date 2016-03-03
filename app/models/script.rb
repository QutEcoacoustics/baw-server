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
  after_create :ensure_updated_by_set

  def display_name
    "#{self.name} - v. #{self.version}"
  end

  def latest_version
    Script
        .where(group_id: self.group_id)
        .order(version: :desc)
        .first
  end

  def is_latest_version?
    self.id == latest_version.id
  end

  def most_recent_in_group
    Script
        .where(group_id: self.group_id)
        .order(created_at: :desc)
        .first
  end

  def is_most_recent_in_group?
    self.id == most_recent_in_group.id
  end

  def master_script
    Script
        .where(group_id: self.group_id)
        .where(id: self.group_id)
        .first
  end

  def all_versions
    Script.where(group_id: self.group_id).order(created_at: :desc)
  end

  def self.all_most_recent_version
    Script.find_by_sql(
        'SELECT s1.*
FROM scripts s1
WHERE s1.version = (
  SELECT max(s2.version)
  FROM scripts s2
  WHERE s1.group_id = s2.group_id
  GROUP BY s2.group_id
)
ORDER BY s1.group_id, s1.version;'
    )
  end

  def self.filter_settings
    {
        valid_fields: [:id, :name, :description, :analysis_identifier, :executable_settings_media_type, :version, :created_at, :creator_id],
        render_fields: [:id, :name, :description, :analysis_identifier, :executable_settings, :executable_settings_media_type, :version, :created_at, :creator_id],
        text_fields: [:name, :description, :analysis_identifier, :executable_settings_media_type],
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
            .where(group_id: self.group_id)
            .where('version >= ?', self.version)
    if matching_or_higher_versions.count > 0
      errors.add(:version, "must be higher than previous versions (#{matching_or_higher_versions.pluck(:version).flatten.join(', ')})")
    end
  end

  def ensure_updated_by_set
    if self.group_id.blank?
      self.group_id = self.id
      self.save
    end
  end

end
