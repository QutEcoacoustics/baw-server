require 'spec_helper'

describe Permission, :type => :model do
  #pending "add some examples to (or delete) #{__FILE__}"

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
end
