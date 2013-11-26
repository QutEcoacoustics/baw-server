#require 'spec_helper'
#
#describe "datasets/new" do
#  before(:each) do
#    assign(:dataset, stub_model(Dataset,
#      :name => "MyString",
#      :filters => "MyString",
#      :number_of_samples => 1,
#      :number_of_tags => 1,
#      :types_of_tags => "MyString",
#      :description => "MyText"
#    ).as_new_record)
#  end
#
#  it "renders new dataset form" do
#    render
#
#    # Run the generator again with the --webrat flag if you want to use webrat matchers
#    assert_select "form[action=?][method=?]", datasets_path, "post" do
#      assert_select "input#dataset_name[name=?]", "dataset[name]"
#      assert_select "input#dataset_filters[name=?]", "dataset[filters]"
#      assert_select "input#dataset_number_of_samples[name=?]", "dataset[number_of_samples]"
#      assert_select "input#dataset_number_of_tags[name=?]", "dataset[number_of_tags]"
#      assert_select "input#dataset_types_of_tags[name=?]", "dataset[types_of_tags]"
#      assert_select "textarea#dataset_description[name=?]", "dataset[description]"
#    end
#  end
#end
