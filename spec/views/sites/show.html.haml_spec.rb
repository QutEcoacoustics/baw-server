#require 'spec_helper'
#
#describe "sites/show" do
#  before(:each) do
#    @site = assign(:site, stub_model(Site,
#      :name => "Name",
#      :longitude => "9.99",
#      :latitude => "9.99",
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
#    rendered.should match(/9.99/)
#    rendered.should match(/9.99/)
#    rendered.should match(/MyText/)
#    rendered.should match(/1/)
#    rendered.should match(/2/)
#    rendered.should match(/3/)
#    rendered.should match(//)
#  end
#end
