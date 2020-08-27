# frozen_string_literal: true

require 'rails_helper'

describe 'rendering markdown' do
  let(:markdown_fixture) {
    <<~MARKDOWN
      # Testy **test**!

      This is a test that tests tests!

      - a list
      - really
      - so many items

      ~~~
        some code
      ~~~

      | Codec | Extension         |
      |-------|-------------------|
      | WAVE  | .wav              |
      | WAC   | .wac              |


      an image ![user](/images/user/user_spanhalf.png)
    MARKDOWN
  }

  it 'converts markdown documents correctly' do
    html = CustomRender.render_markdown(markdown_fixture)

    expect(html).to match '<h1>Testy <strong>test</strong>!</h1>'
    expect(html).to match(%r{<li>a list</li>})
    expect(html).to match(%r{<pre><code>.*some code\n</code></pre>})
    expect(html).to match(%r{<table>[\S\s]*<td>WAVE</td>[\S\s]*</table>})
    expect(html).to match(%r{<img src="/images/user/user_spanhalf\.png"})
  end

  it 'converts markdown via a attr access helper method' do
    html = CustomRender.render_markdown(markdown_fixture, inline: false)

    expect(html).to match '<h1>Testy <strong>test</strong>!</h1>'
    expect(html).to match(%r{<li>a list</li>})
    expect(html).to match(%r{<pre><code>.*some code\n</code></pre>})
    expect(html).to match(%r{<table>[\S\s]*<td>WAVE</td>[\S\s]*</table>})
    expect(html).to match(%r{<img src="/images/user/user_spanhalf\.png"})
  end

  it 'converts markdown via a attr access helper method and can strip block tags' do
    html = CustomRender.render_markdown(markdown_fixture, inline: true)

    expect(html).to_not match '<h1>Testy <strong>test</strong>!</h1>'
    expect(html).to match 'Testy <strong>test</strong>!'
    expect(html).to_not match(%r{<li>a list</li>})
    expect(html).to match 'a list'
    expect(html).to_not match(%r{<pre><code>.*some code\n</code></pre>})
    expect(html).to match 'some code'
    expect(html).to_not match(%r{<table>[\S\s]*<td>WAVE</td>[\S\s]*</table>})
    expect(html).to match(/WAVE\s*.wav/)
    expect(html).to_not match(%r{<img src="/images/user/user_spanhalf\.png"})
    expect(html).to match 'an image'
  end

  context 'values are sanitized' do
    it 'removes script tags' do
      malicious = '<script src="https://www.whatever.org />'
      html = CustomRender.render_model_markdown(malicious, inline: false)
      expect(html).to be_empty
    end
    it 'removes script blocks' do
      malicious = '<script>console.log("i iz l33t hackz0rs")</script>'
      html = CustomRender.render_model_markdown(malicious, inline: false)
      expect(html).to be_empty
    end
  end
end
