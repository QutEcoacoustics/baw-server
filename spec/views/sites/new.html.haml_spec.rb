#require 'rails_helper'
#
#describe "sites/new" do
#  before(:each) do
#    assign(:site, stub_model(Site,
#      :name => "MyString",
#      :longitude => "9.99",
#      :latitude => "9.99",
#      :notes => "MyText",
#      :creator_id => 1,
#      :updater_id => 1,
#      :deleter_id => 1,
#      :image => ""
#    ).as_new_record)
#  end
#
#  it "renders new site form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", sites_path, "post" do
#      assert_select "input#site_name[name=?]", "site[name]"
#      assert_select "input#site_longitude[name=?]", "site[longitude]"
#      assert_select "input#site_latitude[name=?]", "site[latitude]"
#      assert_select "textarea#site_notes[name=?]", "site[notes]"
#      assert_select "input#site_creator_id[name=?]", "site[creator_id]"
#      assert_select "input#site_updater_id[name=?]", "site[updater_id]"
#      assert_select "input#site_deleter_id[name=?]", "site[deleter_id]"
#      assert_select "input#site_image[name=?]", "site[image]"
#    end
#  end
#end
