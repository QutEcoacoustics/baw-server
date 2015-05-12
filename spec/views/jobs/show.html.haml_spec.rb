#require 'spec_helper'
#
#describe "jobs/show" do
#  before(:each) do
#    @job = assign(:job, stub_model(Job,
#      :name => "Name",
#      :description => "Description",
#      :notes => "MyText",
#      :script_id => 2,
#      :creator_id => 3,
#      :updater_id => 4,
#      :deleter_id => 5
#    ))
#  end
#
#  it "renders attributes in <p>" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    rendered.should match(/Name/)
#    rendered.should match(/Description/)
#    rendered.should match(/MyText/)
#    rendered.should match(/2/)
#    rendered.should match(/3/)
#    rendered.should match(/4/)
#    rendered.should match(/5/)
#  end
#end
