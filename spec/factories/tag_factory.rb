require 'faker'

FactoryGirl.define do
  factory :required_tag_attributes, class: Tag do |f|
    is_taxanomic           false
    sequence(:text)        {|n| Faker::Lorem.word + n.to_s}
    type_of_tag            Tag::AVAILABLE_TYPE_OF_TAGS.sample
    retired                false
  end
end

