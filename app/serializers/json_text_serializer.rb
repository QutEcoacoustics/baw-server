# frozen_string_literal: true

# The same as ActiveRecord::Coders::JSON but symbolizes keys.
# See https://github.com/rails/rails/blob/d7ac149f5ff4f6590b6485d358f7c9780d838551/activerecord/lib/active_record/coders/json.rb#L5
class JsonTextSerializer
  def self.dump(obj)
    ActiveSupport::JSON.encode(obj)
  end

  def self.load(json)
    return if json.blank?

    ActiveSupport::JSON.decode(json).deep_symbolize_keys
  end
end
