require 'rails_helper'

describe 'public/index', type: :view do

  standard_text = 'Welcome! This is an Acoustic Workbench website.'

  it 'should render a stock welcome message for new pages' do
    render
    expect(rendered).to include(standard_text)
  end

  it 'should allow the standard welcome message to be replaced' do
    stub_template 'public/_home.md' => <<~MARKDOWN
      This is a testy **test** test
    MARKDOWN

    render
    expect(rendered).to_not include(standard_text)
    expect(rendered).to include('This is a testy <strong>test</strong> test')
  end
end
