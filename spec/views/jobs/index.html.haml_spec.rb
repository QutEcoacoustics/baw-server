#require 'spec_helper'
#
#describe "jobs/index" do
#  before(:each) do
#    assign(:jobs, [
#      stub_model(Job,
#        :name => "Name",
#        :description => "Description",
#        :notes => "MyText",
#        :dataset_id => 1,
#        :script_id => 2,
#        :creator_id => 3,
#        :updater_id => 4,
#        :deleter_id => 5
#      ),
#      stub_model(Job,
#        :name => "Name",
#        :description => "Description",
#        :notes => "MyText",
#        :dataset_id => 1,
#        :script_id => 2,
#        :creator_id => 3,
#        :updater_id => 4,
#        :deleter_id => 5
#      )
#    ])
#  end
#
#  it "renders a list of jobs" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "tr>td", :text => "Name".to_s, :count => 2
#    assert_select "tr>td", :text => "Description".to_s, :count => 2
#    assert_select "tr>td", :text => "MyText".to_s, :count => 2
#    assert_select "tr>td", :text => 1.to_s, :count => 2
#    assert_select "tr>td", :text => 2.to_s, :count => 2
#    assert_select "tr>td", :text => 3.to_s, :count => 2
#    assert_select "tr>td", :text => 4.to_s, :count => 2
#    assert_select "tr>td", :text => 5.to_s, :count => 2
#  end
#end
