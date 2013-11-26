#require 'spec_helper'
#
#describe "datasets/show" do
#  before(:each) do
#    @dataset = assign(:dataset, stub_model(Dataset,
#      :name => "Name",
#      :filters => "Filters",
#      :number_of_samples => 1,
#      :number_of_tags => 2,
#      :types_of_tags => "Types Of Tags",
#      :description => "MyText"
#    ))
#  end
#
#  it "renders attributes in <p>" do
#    render
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    rendered.should match(/Name/)
#    rendered.should match(/Filters/)
#    rendered.should match(/1/)
#    rendered.should match(/2/)
#    rendered.should match(/Types Of Tags/)
#    rendered.should match(/MyText/)
#  end
#end
