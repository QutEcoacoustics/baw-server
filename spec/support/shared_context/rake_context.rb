# frozen_string_literal: true

# Adapted from https://thoughtbot.com/blog/test-rake-tasks-like-a-boss
require 'rake'

shared_context 'rake_spec_context' do
  let(:task_name) { self.class.top_level_description }

  subject { @rake[task_name] }

  around(:each) do |example|
    Dir.chdir Rails.root do
      _ = Rake.with_application { |rake|
        rake.load_rakefile
        @rake = rake
        example.run
      }
    end
  end
end
