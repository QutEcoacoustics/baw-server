FactoryGirl.define do

  factory :saved_search do
    sequence(:name) { |n| "saved search name #{n}" }
    sequence(:description) { |n| "saved search description #{n}" }
    sequence(:stored_query) { |n| {filter: {in: [n]}} }

    creator

  end
end