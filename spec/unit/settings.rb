# frozen_string_literal: true

require 'rails_helper'

describe Settings do
  it { should be_a(Config::Options) }
  it { should be_a_kind_of(BawWeb::Settings) }
  its(:ancestors) { should start_with(BawWeb::Settings, Config::Options) }
  its(:version) { should_not be_nil }
  its(:version) { should be_a(Hash) }
  its(:version_string) { should_not be_blank }
  its(:attributes) {
    should include(
      'supported_media_types',
      'media_category',
      'process_media_locally?',
      'process_media_resque?',
      'min_duration_larger_overlap?'
    )
  }
  its(:supported_media_types) { should include('application/json') }

  its(:sources) { should be(BawApp.config_files.map(&:to_s)) }
end

describe Settings do
  # it should simply be an alias for Settings

  it { should be_a(Config::Options) }
  it { should be_equal(Settings) }
end
