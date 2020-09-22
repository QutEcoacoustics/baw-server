# frozen_string_literal: true

step 'an empty :special directory' do |directory|
  # uses the clear methods in shared context shared_test_helpers
  send("clear_#{directory}".to_sym)
end

step ':special directory should be empty' do |directory|
  path = Pathname.new(send(directory))

  expect(path).to exist
  expect(path).to be_empty
end
