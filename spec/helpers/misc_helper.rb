class MiscHelper
  def create_sha_256_hash(hash_string = nil)
    target_char_count = 64

    hash_string = '' if hash_string.blank?
    chars_needed = target_char_count - hash_string.to_s.length

    # http://stackoverflow.com/a/3572953/31567
    range = [*'0'..'9', *'A'..'Z', *'a'..'z']
    random_chars = Array.new(chars_needed) { range.sample }.join

    "SHA256::#{hash_string}#{random_chars}"
  end

  def format_sql(sql)
    sql
        .gsub('WHERE', "\nWHERE")
        .gsub('INNERJOIN', "\nINNERJOIN")
        .gsub('LEFTOUTERJOIN', "\nLEFTOUTERJOIN")
        .gsub('AND', "\nAND")
        .gsub('FROM', "\nFROM")
        .gsub('OR', "\nOR")
        .gsub('SELECT', "\nSELECT")
  end
end