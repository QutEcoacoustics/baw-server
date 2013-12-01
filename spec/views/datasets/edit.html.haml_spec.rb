require 'spec_helper'

describe 'datasets/edit' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end
  end

  it 'renders the edit dataset form' do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select 'form[action=?][method=?]', project_dataset_path(@project, @dataset), 'post' do
      assert_select 'input#dataset_name[name=?]', 'dataset[name]'
      #assert_select 'input#dataset_filters[name=?]', 'dataset[filters]'
      #assert_select 'input#dataset_number_of_samples[name=?]', 'dataset[number_of_samples]'
      assert_select 'select#dataset_number_of_tags[name=?]', 'dataset[number_of_tags]'
      assert_select 'select#dataset_types_of_tags[name=?]', 'dataset[types_of_tags][]'
      assert_select 'textarea#dataset_description[name=?]', 'dataset[description]'
    end
  end
end
