# frozen_string_literal: true

# == Schema Information
#
# Table name: provenances
#
#  id                                                                     :integer          not null, primary key
#  deleted_at                                                             :datetime
#  description(Markdown description of this source)                       :text
#  name                                                                   :string
#  score_maximum(Upper bound for scores emitted by this source, if known) :decimal(, )
#  score_minimum(Lower bound for scores emitted by this source, if known) :decimal(, )
#  url                                                                    :string
#  version                                                                :string
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  creator_id                                                             :integer
#  deleter_id                                                             :integer
#  updater_id                                                             :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deleter_id => users.id)
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :provenance do
    name { ['Birdnet', 'Perch', 'Acoustic Indices'].sample }
    url { 'https://example.com' }
    sequence(:version) { |n| "#{n}.0.0" }

    creator
  end
end
