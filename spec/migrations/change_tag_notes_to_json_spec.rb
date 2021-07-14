# frozen_string_literal: true


require Rails.root.join('db', 'migrate', '20200612004608_change_tag_notes_to_json.rb')

# TODO: Implement tests
xdescribe 'ChangeTagNotesToJson', :migration do
  # Create test data
  let(:tags) { table(:tags) }
  let(:users) { table(:users) }

  # Test scenarios
  let(:open_brackets) { tags.create!(id: 1, text: 'open_brackets', creator_id: 1, notes: '{{{{{') }
  let(:array) { tags.create!(id: 2, text: 'array', creator_id: 1, notes: [1, 2, 3]) }
  let(:valid_object) { tags.create!(id: 3, text: 'valid_object', creator_id: 1, notes: '{"testing": "data_loss"}') }
  let(:valid_multi_object) { tags.create!(id: 4, text: 'valid_multi_object', creator_id: 1, notes: '{"test": 42,"value": "bob"}') }
  let(:empty_object) { tags.create!(id: 5, text: 'empty_object', creator_id: 1, notes: '{}') }
  let(:single_quotes) { tags.create!(id: 6, text: 'single_quotes', creator_id: 1, notes: '\'\'') }
  let(:double_quotes) { tags.create!(id: 7, text: 'double_quotes', creator_id: 1, notes: '""') }
  let(:object_containing_array) { tags.create!(id: 8, text: 'object_containing_array', creator_id: 1, notes: '{"123": [1,2,3]}') }
  let(:empty_string) { tags.create!(id: 9, text: 'empty_string', creator_id: 1, notes: '') }
  let(:null) { tags.create!(id: 10, text: 'null', creator_id: 1, notes: nil) }

  before do
    # Create user?
    # users.create!(
    #   id: 1,
    #   user_name: 'test_user',
    #   email: 'a@c.com',
    #   encrypted_password: '$2a$10$xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
    # )
  end

  it 'should handle open brackets' do
    tags.create!(id: 1, text: 'open_brackets', creator_id: 1, notes: '{{{{{')
    migrate!
    expect(tags.count).to eq 1
    #expect(tags.all.pluck(:notes)).to match_array []
  end
end
