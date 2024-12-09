# frozen_string_literal: true

# == Schema Information
#
# Table name: projects_sites
#
#  project_id :integer          not null, primary key
#  site_id    :integer          not null, primary key
#
# Indexes
#
#  index_projects_sites_on_project_id              (project_id)
#  index_projects_sites_on_project_id_and_site_id  (project_id,site_id)
#  index_projects_sites_on_site_id                 (site_id)
#
# Foreign Keys
#
#  projects_sites_project_id_fk  (project_id => projects.id)
#  projects_sites_site_id_fk     (site_id => sites.id) ON DELETE => cascade
#
class ProjectsSite < ApplicationRecord
  self.table_name = 'projects_sites'
  self.primary_key = [:project_id, :site_id]

  belongs_to :project
  belongs_to :site
end
