require 'spec_helper'

describe "audio_event_comments/show" do
  before(:each) do
    @audio_event_comment = assign(:audio_event_comment, stub_model(AudioEventComment))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
  end
end
