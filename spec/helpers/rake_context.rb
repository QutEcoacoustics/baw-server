# frozen_string_literal: true

# Adapted from https://thoughtbot.com/blog/test-rake-tasks-like-a-boss
require 'rake'

shared_context 'rake' do
  let(:rake)      { Rake::Application.new }
  let(:task_name) { self.class.top_level_description }

  subject         { rake[task_name] }

  before do
    Rake.application = rake
    Rake.application.init
    Rake.application.load_rakefile

    Rake::Task.define_task(:environment)
  end
end
