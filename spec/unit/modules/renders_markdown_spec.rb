

describe RendersMarkdown do
  before(:all) do
    ActiveRecord::Base.connection.drop_table :temp_model_markdown_tests, if_exists: true
    connection = ActiveRecord::Base.connection
    connection.create_table :temp_model_markdown_tests do |t|
      t.column :some_long_text, :string
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :temp_model_markdown_tests
  end

  subject do
    class TempModelMarkdownTest < ApplicationRecord
      renders_markdown_for :some_long_text
    end

    return TempModelMarkdownTest.new
  end

  describe 'dynamic attribute' do
    it 'defines a dynamic attribute with the `renders_markdown_for` call' do
      expect(subject).to respond_to(:some_long_text_html)
    end

    it 'is really just a proxy for the generic method' do
      instance = subject

      expect(instance).to receive(:render_markdown_for).once

      instance.some_long_text_html
    end
  end

  describe 'render methods' do
    example 'rendering markdown' do
      subject.some_long_text = '# **hello**'
      expect(subject.render_markdown_for(:some_long_text)).to eq("<h1 id=\"hello\"><strong>hello</strong></h1>\n")
    end

    example 'rendering markdown tagline' do
      # 'remains' is the 35th word - the default truncation point
      # text also tests whether html tags are split during truncation
      subject.some_long_text = <<~MARKDOWN
        # **Hello darkness**, my old friend
        I've come to talk with you again
        Because a vision softly creeping
        _Left its seeds while I was sleeping_
        And the vision that was planted in my brain
        _Still remains
        Within the sound of silence_
      MARKDOWN

      expected = '<strong>Hello darkness</strong>, my old friend I’ve come to talk with you again '\
        'Because a vision softly creeping <em>Left its seeds while I was sleeping</em> ' \
        'And the vision that was planted in my brain <em>Still remains...</em>'

      expect(
        subject.render_markdown_tagline_for(:some_long_text)
      ).to eq expected
    end

    example 'rendering markdown tagline (different word length)' do
      subject.some_long_text = <<~MARKDOWN
        # In restless dreams I walked _alone_
        Narrow streets of cobblestone
        ’Neath the halo of a street lamp
        I turned my collar to the cold and damp
        When my eyes were stabbed by the flash of a neon light
        That split the night
        And touched the sound of silence
      MARKDOWN
      expect(
        subject.render_markdown_tagline_for(:some_long_text, words: 11)
      ).to eq('In restless dreams I walked <em>alone</em> Narrow streets of cobblestone ’Neath...')
    end

    example 'rendering markdown for api' do
      subject.some_long_text = '# **hello**'
      expect(subject.render_markdown_for_api_for(:some_long_text)).to eq({
        some_long_text_html: "<h1 id=\"hello\"><strong>hello</strong></h1>\n",
        some_long_text_html_tagline: '<strong>hello</strong>'
      })
    end
  end
end
