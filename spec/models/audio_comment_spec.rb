# frozen_string_literal: true

require 'rails_helper'

describe AudioEventComment, type: :model do
  # .with_predicates(true).with_multiple(false)
  it { is_expected.to enumerize(:flag).in(*AudioEventComment::AVAILABLE_FLAGS) }
end
