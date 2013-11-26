#require 'spec_helper'
#
#describe "permissions/index" do
#  before(:each) do
#    assign(:permissions, [
#      stub_model(Permission,
#        :creator_id => 1,
#        :level => "Level",
#        :project_id => 2,
#        :user_id => 3
#      ),
#      stub_model(Permission,
#        :creator_id => 1,
#        :level => "Level",
#        :project_id => 2,
#        :user_id => 3
#      )
#    ])
#  end
#
#  it "renders a list of permissions" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "tr>td", :text => 1.to_s, :count => 2
#    assert_select "tr>td", :text => "Level".to_s, :count => 2
#    assert_select "tr>td", :text => 2.to_s, :count => 2
#    assert_select "tr>td", :text => 3.to_s, :count => 2
#  end
#end
