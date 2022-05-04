# frozen_string_literal: true

class HashSerializer
  def self.dump(hash)
    hash
  end

  def self.load(hash)
    (hash || {}).deep_symbolize_keys.with_indifferent_access
  end
end
