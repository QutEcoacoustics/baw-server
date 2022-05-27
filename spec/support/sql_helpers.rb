# frozen_string_literal: true

module SqlHelpers
  module Example
    # Compares two SQL statements.
    # It does this by inserting newlines before any capitalized word and by squashing whitespace down into a single space.
    # This triggers the multi line differ which is far far easier to work with.
    def comparison_sql(actual, expected)
      a_mod = actual.gsub(/\s*([A-Z][A-Z]+)/, "\n\\1").gsub(/(\t| )+/, ' ').trim('\n')
      b_mod = expected.gsub(/\s*([A-Z][A-Z]+)/, "\n\\1").gsub(/(\t| )+/, ' ').trim('\n')
      expect(a_mod).to eq(b_mod)
    end
  end
end
