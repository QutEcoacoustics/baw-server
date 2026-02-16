# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs_scripts
#
#  custom_settings(Custom settings for this script and analysis job)                                             :text
#  event_import_include_top(Limit import to the top N results per tag per file, custom to this analysis job)     :integer
#  event_import_include_top_per(Apply top filtering per this interval, in seconds, custom to this analysis job)  :integer
#  event_import_minimum_score(Minimum score threshold for importing events, if any, custom to this analysis job) :decimal(, )
#  analysis_job_id                                                                                               :integer          not null, primary key
#  script_id                                                                                                     :integer          not null, primary key
#
# Foreign Keys
#
#  fk_rails_...  (analysis_job_id => analysis_jobs.id) ON DELETE => cascade
#  fk_rails_...  (script_id => scripts.id)
#
class AnalysisJobsScript < ApplicationRecord
  self.table_name = 'analysis_jobs_scripts'
  self.primary_key = [:analysis_job_id, :script_id]

  belongs_to :analysis_job
  belongs_to :script

  validates :custom_settings, length: { minimum: 1, maximum: 512.kilobytes }, allow_nil: true
  validates :event_import_minimum_score, allow_nil: true, numericality: true
  validates :event_import_include_top, allow_nil: true, numericality: { only_integer: true, greater_than: 0 }
  validates :event_import_include_top_per, allow_nil: true, numericality: { only_integer: true, greater_than: 0 }
  validate :top_filtering_consistent

  private

  def top_filtering_consistent
    # event_import_include_top_per depends on event_import_include_top, but event_import_include_top can work alone
    return if event_import_include_top_per.nil? || event_import_include_top.present?

    errors.add(:event_import_include_top_per, 'can only be set when event_import_include_top is also set')
  end
end
