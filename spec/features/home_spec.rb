require 'rails_helper'

describe 'visiting the homepage', :type => :feature do
  before do
    visit '/'
    @left_menu = page.all(".left-nav-bar nav[role=navigation] li")
  end

  it 'should have a body' do
    expect(page).to have_css('body')    
  end

  context 'left hand navigation menu' do

    it {
      @left_menu[0][:class].include?('active').should be_truthy
    }

    it {
      @left_menu[0].should have_css('i.fa.fa-fw')
      @left_menu[0].should have_css('i.fa-home')
    }

  end

end
