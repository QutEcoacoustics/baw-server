#require 'spec_helper'
#
#describe "projects/new" do
#  before(:each) do
#    assign(:project, stub_model(Project,
#      :name => "MyString",
#      :description => "MyText",
#      :urn => "MyString",
#      :notes => "MyText",
#      :creator_id => 1,
#      :updater_id => 1,
#      :deleter_id => 1,
#      :image => ""
#    ).as_new_record)
#  end
#
#  it "renders new project form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", projects_path, "post" do
#      assert_select "input#project_name[name=?]", "project[name]"
#      assert_select "textarea#project_description[name=?]", "project[description]"
#      assert_select "input#project_urn[name=?]", "project[urn]"
#      assert_select "textarea#project_notes[name=?]", "project[notes]"
#      assert_select "input#project_creator_id[name=?]", "project[creator_id]"
#      assert_select "input#project_updater_id[name=?]", "project[updater_id]"
#      assert_select "input#project_deleter_id[name=?]", "project[deleter_id]"
#      assert_select "input#project_image[name=?]", "project[image]"
#    end
#  end
#end
