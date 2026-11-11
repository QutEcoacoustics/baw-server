# frozen_string_literal: true

# == Schema Information
#
# Table name: saved_searches
#
#  id           :integer          not null, primary key
#  deleted_at   :datetime
#  description  :text
#  name         :string           not null
#  stored_query :jsonb            not null
#  created_at   :datetime         not null
#  creator_id   :integer          not null
#  deleter_id   :integer
#
# Foreign Keys
#
#  saved_searches_creator_id_fk  (creator_id => users.id)
#  saved_searches_deleter_id_fk  (deleter_id => users.id)
#
FactoryBot.define do
  factory :saved_search do
    sequence(:name) { |n| "saved search name #{n}" }
    sequence(:description) { |n| "saved search description #{n}" }
    sequence(:stored_query) { |_n| { uuid: { eq: 'blah blah' } } }

    creator

    factory :saved_search_with_projects do
      after(:create) do |saved_search, _evaluator|
        saved_search.projects << Project.all
      end
    end
  end
end
