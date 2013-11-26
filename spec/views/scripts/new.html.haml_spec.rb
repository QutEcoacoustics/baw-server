#require 'spec_helper'
#
#describe "scripts/new" do
#  before(:each) do
#    assign(:script, stub_model(Script,
#      :name => "MyString",
#      :description => "MyString",
#      :notes => "MyText",
#      :settings_file => "",
#      :data_file => "",
#      :analysis_identifier => "MyString"
#    ).as_new_record)
#  end
#
#  it "renders new script form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", scripts_path, "post" do
#      assert_select "input#script_name[name=?]", "script[name]"
#      assert_select "input#script_description[name=?]", "script[description]"
#      assert_select "textarea#script_notes[name=?]", "script[notes]"
#      assert_select "input#script_settings_file[name=?]", "script[settings_file]"
#      assert_select "input#script_data_file[name=?]", "script[data_file]"
#      assert_select "input#script_analysis_identifier[name=?]", "script[analysis_identifier]"
#    end
#  end
#end
