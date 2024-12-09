# frozen_string_literal: true

# == Schema Information
#
# Table name: projects_saved_searches
#
#  project_id      :integer          not null, primary key
#  saved_search_id :integer          not null, primary key
#
# Indexes
#
#  index_projects_saved_searches_on_project_id                      (project_id)
#  index_projects_saved_searches_on_project_id_and_saved_search_id  (project_id,saved_search_id)
#  index_projects_saved_searches_on_saved_search_id                 (saved_search_id)
#
# Foreign Keys
#
#  projects_saved_searches_project_id_fk       (project_id => projects.id) ON DELETE => cascade
#  projects_saved_searches_saved_search_id_fk  (saved_search_id => saved_searches.id)
#
class ProjectsSavedSearch < ApplicationRecord
  self.table_name = 'projects_saved_searches'
  self.primary_key = [:project_id, :saved_search_id]

  belongs_to :project
  belongs_to :saved_search
end
