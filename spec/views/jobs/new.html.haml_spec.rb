#require 'spec_helper'
#
#describe "jobs/new" do
#  before(:each) do
#    assign(:job, stub_model(Job,
#      :name => "MyString",
#      :description => "MyString",
#      :notes => "MyText",
#      :dataset_id => 1,
#      :script_id => 1,
#      :creator_id => 1,
#      :updater_id => 1,
#      :deleter_id => 1
#    ).as_new_record)
#  end
#
#  it "renders new job form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", jobs_path, "post" do
#      assert_select "input#job_name[name=?]", "job[name]"
#      assert_select "input#job_description[name=?]", "job[description]"
#      assert_select "textarea#job_notes[name=?]", "job[notes]"
#      assert_select "input#job_dataset_id[name=?]", "job[dataset_id]"
#      assert_select "input#job_script_id[name=?]", "job[script_id]"
#      assert_select "input#job_creator_id[name=?]", "job[creator_id]"
#      assert_select "input#job_updater_id[name=?]", "job[updater_id]"
#      assert_select "input#job_deleter_id[name=?]", "job[deleter_id]"
#    end
#  end
#end
