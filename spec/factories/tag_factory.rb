require 'faker'

FactoryGirl.define do
  factory :required_tag_attributes, class: Tag do |f|
    is_taxanomic           false
    sequence(:text)        {|n| Faker::Lorem.word + n.to_s}
    type_of_tag            [:general, :common_name, :species_name, :looks_like, :sounds_like].sample
    retired                false
  end
end

