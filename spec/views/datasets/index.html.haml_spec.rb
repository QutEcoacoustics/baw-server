#require 'spec_helper'
#
#describe "datasets/index" do
#  before(:each) do
#    assign(:datasets, [
#      stub_model(Dataset,
#        :name => "Name",
#        :filters => "Filters",
#        :number_of_samples => 1,
#        :number_of_tags => 2,
#        :types_of_tags => "Types Of Tags",
#        :description => "MyText"
#      ),
#      stub_model(Dataset,
#        :name => "Name",
#        :filters => "Filters",
#        :number_of_samples => 1,
#        :number_of_tags => 2,
#        :types_of_tags => "Types Of Tags",
#        :description => "MyText"
#      )
#    ])
#  end
#
#  it "renders a list of datasets" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "tr>td", :text => "Name".to_s, :count => 2
#    assert_select "tr>td", :text => "Filters".to_s, :count => 2
#    assert_select "tr>td", :text => 1.to_s, :count => 2
#    assert_select "tr>td", :text => 2.to_s, :count => 2
#    assert_select "tr>td", :text => "Types Of Tags".to_s, :count => 2
#    assert_select "tr>td", :text => "MyText".to_s, :count => 2
#  end
#end
