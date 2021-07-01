# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id           :integer          not null, primary key
#  is_taxonomic :boolean          default(FALSE), not null
#  notes        :jsonb
#  retired      :boolean          default(FALSE), not null
#  text         :string           not null
#  type_of_tag  :string           default("general"), not null
#  created_at   :datetime
#  updated_at   :datetime
#  creator_id   :integer          not null
#  updater_id   :integer
#
# Indexes
#
#  index_tags_on_creator_id  (creator_id)
#  index_tags_on_updater_id  (updater_id)
#  tags_text_uidx            (text) UNIQUE
#
# Foreign Keys
#
#  tags_creator_id_fk  (creator_id => users.id)
#  tags_updater_id_fk  (updater_id => users.id)
#
FactoryBot.define do
  factory :tag do |_f|
    sequence(:text) { |n| "tag text #{n}" }

    creator
    type_of_tag { 'general' }
    is_taxonomic { false }

    trait :taxonomic_true_common do
      is_taxonomic { true }
      type_of_tag { :common_name }
    end

    trait :taxonomic_false_sounds_like do
      is_taxonomic { false }
      type_of_tag { :sounds_like }
    end

    trait :retired do
      retired { true }
    end

    trait :notes do
      notes { { 'comment' => 'value' } }
    end

    factory :tag_taxonomic_true_common, traits: [:taxonomic_true_common]
    factory :tag_taxonomic_true_common_notes, traits: [:tag_taxonomic_true_common, :notes]
    factory :tag_taxonomic_false_sounds_like, traits: [:taxonomic_false_sounds_like]
    factory :tag_retired_taxonomic_true_common, traits: [:taxonomic_true_common, :retired]
    factory :tag_retired_taxonomic_false_sounds_like, traits: [:taxonomic_false_sounds_like, :retired]
  end
end
