require 'spec_helper'

describe "audio_event_comments/edit" do
  before(:each) do
    @audio_event_comment = assign(:audio_event_comment, stub_model(AudioEventComment))
  end

  it "renders the edit audio_event_comment form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", audio_event_comment_path(@audio_event_comment), "post" do
    end
  end
end
