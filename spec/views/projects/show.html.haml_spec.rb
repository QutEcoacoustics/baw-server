#require 'spec_helper'
#
#describe "projects/show" do
#  before(:each) do
#    @project = assign(:project, stub_model(Project,
#      :name => "Name",
#      :description => "MyText",
#      :urn => "Urn",
#      :notes => "MyText",
#      :creator_id => 1,
#      :updater_id => 2,
#      :deleter_id => 3,
#      :image => ""
#    ))
#  end
#
#  it "renders attributes in <p>" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    rendered.should match(/Name/)
#    rendered.should match(/MyText/)
#    rendered.should match(/Urn/)
#    rendered.should match(/MyText/)
#    rendered.should match(/1/)
#    rendered.should match(/2/)
#    rendered.should match(/3/)
#    rendered.should match(//)
#  end
#end
