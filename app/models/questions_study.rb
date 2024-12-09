# frozen_string_literal: true

# == Schema Information
#
# Table name: questions_studies
#
#  question_id :integer          not null, primary key
#  study_id    :integer          not null, primary key
#
# Foreign Keys
#
#  fk_rails_...  (question_id => questions.id)
#  fk_rails_...  (study_id => studies.id)
#
class QuestionsStudy < ApplicationRecord
  self.table_name = 'questions_studies'
  self.primary_key = [:question_id, :study_id]

  belongs_to :question
  belongs_to :study
end
