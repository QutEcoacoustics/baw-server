require 'rails_helper'

describe 'alphabetical paginator activerecord extension' do
  before :each do
    FactoryGirl.build(:user, user_name: '汉字 user').save(validate: false)
    FactoryGirl.create(:user, user_name: 'aauser')
    FactoryGirl.create(:user, user_name: 'anuser')
    FactoryGirl.create(:user, user_name: 'amuser')
    FactoryGirl.create(:user, user_name: 'azuser')
    FactoryGirl.create(:user, user_name: 'buser')
    FactoryGirl.create(:user, user_name: 'zzzzzuser')
    FactoryGirl.create(:user, user_name: '_user')
    FactoryGirl.create(:user, user_name: '123user')
  end

  it 'returns users in the other range' do
    users = User.alphabetical_page(:user_name, "\u{1F30F}")
    expect(users.count).to eq(2)
    expect(users[0].user_name).to eq('_user')
    expect(users[1].user_name).to eq('汉字 user')
  end

  it 'returns users in the number range' do
    users = User.alphabetical_page(:user_name, '0-9')
    expect(users.count).to eq(1)
    expect(users[0].user_name).to eq('123user')
  end

  it 'returns users in the a-a range' do
    users = User.alphabetical_page(:user_name, 'a-a')
    expect(users.count).to eq(5)
    expect(users[0].user_name).to eq('aauser')
    expect(users[1].user_name).to eq('Admin')
    expect(users[2].user_name).to eq('amuser')
    expect(users[3].user_name).to eq('anuser')
    expect(users[4].user_name).to eq('azuser')
  end

  it 'returns users in the a-b range' do
    users = User.alphabetical_page(:user_name, 'a-b')
    expect(users.count).to eq(6)
    expect(users[0].user_name).to eq('aauser')
    expect(users[1].user_name).to eq('Admin')
    expect(users[2].user_name).to eq('amuser')
    expect(users[3].user_name).to eq('anuser')
    expect(users[4].user_name).to eq('azuser')
    expect(users[5].user_name).to eq('buser')
  end

  it 'returns users in the z-z range' do
    users = User.alphabetical_page(:user_name, 'z-z')
    expect(users.count).to eq(1)
    expect(users[0].user_name).to eq('zzzzzuser')
  end

  it 'returns users in the yzz-zzz range' do
    users = User.alphabetical_page(:user_name, 'yzz-zzz')
    expect(users.count).to eq(1)
    expect(users[0].user_name).to eq('zzzzzuser')
  end

  it 'returns users in the an-am range' do
    users = User.alphabetical_page(:user_name, 'am-an')
    expect(users.count).to eq(2)
    expect(users[0].user_name).to eq('amuser')
    expect(users[1].user_name).to eq('anuser')
  end

  context 'optimization for matching arguments' do
    it 'uses a simpler query format for ranges with indentical left and rights' do
      query = User.alphabetical_page(:user_name, 'aaa-aaa').to_sql
      expect(query).to include('LOWER(LEFT("user_name", 3)) = \'aaa\'')
      expect(query).to match(/WHERE..LOWER(?!.*LOWER)/)
    end
  end

  context 'validating arguments' do
    cases = [
        '1-2',
        "\u{1F30D}",
        "\u{1F30F}-\u{1F30F}",
        '汉-字',
        'a1-a2',
        '---',
        '\';-- SELECT * FROM users',
        'A-Z',
        'aA-ab',
        'aa-zZ'
    ]

    cases.each do |bad_case|
      it "fails to process an invalid case ('#{bad_case}')" do
        expect {
          User.alphabetical_page(:user_name, bad_case)
        }.to raise_error(ArgumentError, 'Alphabetical paginator range invalid')
      end
    end
  end
end
