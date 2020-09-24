# frozen_string_literal: true

require 'rails_helper'

def update_page(slug, text)
  page = Comfy::Cms::Page.where(slug: slug).first
  fragment = page.fragments.where(identifier: 'content').first
  fragment.content = text
  fragment.save
end

describe '/credits', type: :request do
  create_standard_cms_pages

  before do
    update_page('credits', t = <<~MARKDOWN
      ## If you like piña coladas
      **And getting caught in the** rain
      If you're not into yoga
      If you have half a brain
      If you like making love at midnight
      In the dunes on the cape
      Then I'm the love that you've looked for
      Write to me, and escape
    MARKDOWN
    )
  end

  it 'should render the CMS page' do
    get '/credits'

    expect(response_body).to include(
      <<~HTML
        <h2 id="if-you-like-pia-coladas">If you like piña coladas</h2>
        <p><strong>And getting caught in the</strong> rain
        If you’re not into yoga
        If you have half a brain
        If you like making love at midnight
        In the dunes on the cape
        Then I’m the love that you’ve looked for
        Write to me, and escape</p>
      HTML
    )
  end
end

describe '/data_upload', type: :request do
  create_standard_cms_pages

  before do
    update_page('data_upload', <<~MARKDOWN
      ## I was tired of my lady
      We'd been together too long
      Like a worn out recording
      Of a favorite song
      So while she lay there sleeping
      I read the paper in bed
      And in the personal columns
      **There was this letter I read**
    MARKDOWN
    )
  end

  it 'should render the CMS page' do
    get '/data_upload'

    expect(response_body).to include(
      <<~HTML
        <h2 id="i-was-tired-of-my-lady">I was tired of my lady</h2>
        <p>We’d been together too long
        Like a worn out recording
        Of a favorite song
        So while she lay there sleeping
        I read the paper in bed
        And in the personal columns
        <strong>There was this letter I read</strong></p>
      HTML
    )
  end
end

describe '/ethics', type: :request do
  create_standard_cms_pages

  before do
    update_page('ethics', <<~MARKDOWN
      ## I didn't think about my lady
      I know that sounds kind of mean
      But me and my old lady
      Had fallen into the same old dull routine
      _So I wrote to the paper_
      Took out a personal ad
      And though I'm nobody's poet
      I thought it wasn't half bad
    MARKDOWN
    )
  end

  it 'should render the CMS page' do
    get '/ethics_statement'

    expect(response_body).to include(
      <<~HTML
        <h2 id="i-didnt-think-about-my-lady">I didn’t think about my lady</h2>
        <p>I know that sounds kind of mean
        But me and my old lady
        Had fallen into the same old dull routine
        <em>So I wrote to the paper</em>
        Took out a personal ad
        And though I’m nobody’s poet
        I thought it wasn’t half bad</p>
      HTML
    )
  end
end

describe '/privacy', type: :request do
  create_standard_cms_pages

  before do
    update_page('privacy', <<~MARKDOWN
      "Yes, I like piña coladas
      And getting caught in the rain
      I'm not much into health food
      I am into champagne
      I've got to meet you by tomorrow noon
      And cut through all this red tape
      At a bar called O'Malley's
      Where we'll plan our escape"
    MARKDOWN
    )
  end

  it 'should render the CMS page' do
    get '/disclaimers'

    expect(response_body).to include(
      <<~HTML
        <p>“Yes, I like piña coladas
        And getting caught in the rain
        I’m not much into health food
        I am into champagne
        I’ve got to meet you by tomorrow noon
        And cut through all this red tape
        At a bar called O’Malley’s
        Where we’ll plan our escape”</p>
      HTML
    )
  end
end

describe '/', type: :request do
  create_standard_cms_pages

  before do
    update_page('index', <<~MARKDOWN
      "Yes, I like piña coladas
      And getting caught in the rain
      I'm not much into health food
      I am into champagne
      I've got to meet you by tomorrow noon
      And cut through all this red tape
      At a bar called O'Malley's
      Where we'll plan our escape"
    MARKDOWN
    )
  end

  it 'should render the CMS page' do
    get '/'

    expect(response_body).to include(
      <<~HTML
        <p>“Yes, I like piña coladas
        And getting caught in the rain
        I’m not much into health food
        I am into champagne
        I’ve got to meet you by tomorrow noon
        And cut through all this red tape
        At a bar called O’Malley’s
        Where we’ll plan our escape”</p>
      HTML
    )
  end
end

describe '/status.json' do
  before(:each) do
    BawWorkers::Config.original_audio_helper.possible_dirs.each { |path|
      FileUtils.mkdir_p(path)
    }
  end

  example 'everything ok' do
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'good',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'Alive'
    })
  end

  example 'timeout (storage)' do
    allow(AudioRecording).to receive(:check_storage) {
      # simulate timeout
      (1..120).each { |i| puts i; sleep(0.25) }
      raise 'This should not happen'
    }
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: true,
      database: 'unknown',
      redis: 'unknown',
      storage: 'unknown',
      upload: 'unknown'
    })
  end

  example 'redis cant connect' do
    allow(BawWorkers::Config.redis_communicator).to \
      receive(:ping)
      .and_raise(Redis::CannotConnectError, 'message')
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'error: message',
      storage: '1 audio recording storage directory available.',
      upload: 'Alive'
    })
  end

  example 'upload service, bad storage' do
    stub_request(:get, 'upload:8080/api/v1/providerstatus')
      .to_return(body: '{"message":"abc", "error": "error message"}', status: 500, headers: {content_type: 'application/json'})

    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'abc. error message'
    })
  end

  example 'upload service, time out' do
    stub_request(:get, 'upload:8080/api/v1/providerstatus')
      .to_timeout

    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'error: execution expired'
    })
  end
end
