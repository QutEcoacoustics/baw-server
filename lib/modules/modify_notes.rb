module ModifyNotes
  private

  def get_hash_value(hash, key)
    key_s = key.to_s
    if hash.blank?
      ''
    elsif hash.include?(key_s)
      hash[key_s]
    end
  end

  def set_hash_value(hash, key, value)
    key_s = key.to_s
    hash = {} if hash.blank?
    hash[key_s] = value
    hash
  end
end