FactoryGirl.define do

  factory :tag do |f|
    sequence(:text) { |n| "tag text #{n}" }
    sequence(:notes) { |n| "note number #{n}" }

    type_of_tag 'general'
    is_taxanomic false

    association :creator

    trait :taxonomic_true_common do
      is_taxanomic true
      type_of_tag :common_name
    end

    trait :taxonomic_false_sounds_like do
      is_taxanomic false
      type_of_tag :sounds_like
    end

    trait :retired do
      retired true
    end

    factory :tag_taxonomic_true_common, traits: [:taxonomic_true_common]
    factory :tag_taxonomic_false_sounds_like, traits: [:taxonomic_false_sounds_like]
    factory :tag_retired_taxonomic_true_common, traits: [:taxonomic_true_common, :retired]
    factory :tag_retired_taxonomic_false_sounds_like, traits: [:taxonomic_false_sounds_like, :retired]
  end
end

