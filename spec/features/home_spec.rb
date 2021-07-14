# frozen_string_literal: true



xdescribe 'visiting the homepage', type: :feature do
  before do
    visit '/'
    @left_menu = page.all('.left-nav-bar nav[role=navigation] li')
  end

  it 'should have a body' do
    expect(page).to have_css('body')
  end

  context 'left hand navigation menu' do
    it do
      @left_menu[0][:class].include?('active').should be_truthy
    end

    it {
      @left_menu[0].should have_css('i.fa.fa-fw')
      @left_menu[0].should have_css('i.fa-home')
    }
  end
end
