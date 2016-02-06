#require 'rails_helper'
#
#describe "scripts/index" do
#  before(:each) do
#    assign(:scripts, [
#      stub_model(Script,
#        :name => "Name",
#        :description => "Description",
#        :notes => "MyText",
#        :settings_file => "",
#        :data_file => "",
#        :analysis_identifier => "Analysis Identifier"
#      ),
#      stub_model(Script,
#        :name => "Name",
#        :description => "Description",
#        :notes => "MyText",
#        :settings_file => "",
#        :data_file => "",
#        :analysis_identifier => "Analysis Identifier"
#      )
#    ])
#  end
#
#  it "renders a list of scripts" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "tr>td", :text => "Name".to_s, :count => 2
#    assert_select "tr>td", :text => "Description".to_s, :count => 2
#    assert_select "tr>td", :text => "MyText".to_s, :count => 2
#    assert_select "tr>td", :text => "".to_s, :count => 2
#    assert_select "tr>td", :text => "".to_s, :count => 2
#    assert_select "tr>td", :text => "Analysis Identifier".to_s, :count => 2
#  end
#end
