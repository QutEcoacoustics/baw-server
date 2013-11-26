#require 'spec_helper'
#
#describe "permissions/edit" do
#  before(:each) do
#    @permission = assign(:permission, stub_model(Permission,
#      :creator_id => 1,
#      :level => "MyString",
#      :project_id => 1,
#      :user_id => 1
#    ))
#  end
#
#  it "renders the edit permission form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", permission_path(@permission), "post" do
#      assert_select "input#permission_creator_id[name=?]", "permission[creator_id]"
#      assert_select "input#permission_level[name=?]", "permission[level]"
#      assert_select "input#permission_project_id[name=?]", "permission[project_id]"
#      assert_select "input#permission_user_id[name=?]", "permission[user_id]"
#    end
#  end
#end
