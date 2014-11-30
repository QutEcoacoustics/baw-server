require 'spec_helper'

describe 'visiting the homepage', :type => :feature do
  before do
    visit '/'
  end

  it 'should have a body' do
    expect(page).to have_css('body')    
  end
end
