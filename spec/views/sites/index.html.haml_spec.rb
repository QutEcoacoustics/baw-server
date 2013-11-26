#require 'spec_helper'
#
#describe "sites/index" do
#  before(:each) do
#    assign(:sites, [
#      stub_model(Site,
#        :name => "Name",
#        :longitude => "9.99",
#        :latitude => "9.99",
#        :notes => "MyText",
#        :creator_id => 1,
#        :updater_id => 2,
#        :deleter_id => 3,
#        :image => ""
#      ),
#      stub_model(Site,
#        :name => "Name",
#        :longitude => "9.99",
#        :latitude => "9.99",
#        :notes => "MyText",
#        :creator_id => 1,
#        :updater_id => 2,
#        :deleter_id => 3,
#        :image => ""
#      )
#    ])
#  end
#
#  it "renders a list of sites" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "tr>td", :text => "Name".to_s, :count => 2
#    assert_select "tr>td", :text => "9.99".to_s, :count => 2
#    assert_select "tr>td", :text => "9.99".to_s, :count => 2
#    assert_select "tr>td", :text => "MyText".to_s, :count => 2
#    assert_select "tr>td", :text => 1.to_s, :count => 2
#    assert_select "tr>td", :text => 2.to_s, :count => 2
#    assert_select "tr>td", :text => 3.to_s, :count => 2
#    assert_select "tr>td", :text => "".to_s, :count => 2
#  end
#end
