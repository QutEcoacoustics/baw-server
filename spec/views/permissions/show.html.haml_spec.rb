#require 'spec_helper'
#
#describe "permissions/show" do
#  before(:each) do
#    @permission = assign(:permission, stub_model(Permission,
#      :creator_id => 1,
#      :level => "Level",
#      :project_id => 2,
#      :user_id => 3
#    ))
#  end
#
#  it "renders attributes in <p>" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    rendered.should match(/1/)
#    rendered.should match(/Level/)
#    rendered.should match(/2/)
#    rendered.should match(/3/)
#  end
#end
