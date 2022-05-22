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

  # Changes the file extension of the file this harvest_item represents.
  # Touches the file on disk and updates the database!
  def change_file_extension!(new_extension)
    rel_path = Pathname(path)
    new_rel_path = rel_path.sub_ext(
      "#{rel_path.extname}.#{new_extension.delete_prefix('.')}"
    )

    logger.info('Changing file extension', path: rel_path, new_path: new_rel_path)

    old_path = absolute_path
    self.path = new_rel_path
    new_path = absolute_path

    old_path.rename(new_path)

    save!
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

    #debugger
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

  DEFAULT_COUNTS_BY_STATUS = STATUSES.product([0]).to_h
  def self.counts_by_status(relation)
    DEFAULT_COUNTS_BY_STATUS.merge(relation.group(:status).count)
  end
end
