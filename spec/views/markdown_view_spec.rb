# frozen_string_literal: true

require 'rails_helper'

describe 'rendering markdown partials', type: :view do
  let(:markdown_fixture) {
    <<~MARKDOWN
      # Test!

      This is a test that tests tests!
      
      - a list
      - really
      - so many items
      
      ~~~
      <%= 1 + 1 %> 
      <%= current_user&.user_name %>
      ~~~
      
      an image ![user](/images/user/user_spanhalf.png)
    MARKDOWN
  }

  before(:each) do
    @user = FactoryBot.create(:user)
    #login_as @user, scope: :user
    allow(view).to receive(:current_user).and_return(@user)
  end

  it 'converts markdown documents correctly' do
    stub_template 'public/_markdown_test.html.md' => markdown_fixture
    render partial: 'public/markdown_test'

    expect(rendered).to match(%r{<h1>Test!</h1>})
    expect(rendered).to match(%r{<li>a list</li>})
    expect(rendered).to match(/<code>2/)
    expect(rendered).to match "#{@user.user_name}\n<\/code>"
    expect(rendered).to match(%r{<img src="/images/user/user_spanhalf\.png"})
  end
end
