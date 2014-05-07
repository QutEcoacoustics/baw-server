require 'spec_helper'

describe Permission do
  #pending "add some examples to (or delete) #{__FILE__}"

  it { should belong_to(:creator).with_foreign_key(:creator_id) }
  it { should belong_to(:updater).with_foreign_key(:updater_id) }
end
