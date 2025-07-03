# frozen_string_literal: true

module PBS
  Result = Data.define(:status, :stdout, :stderr, :message) {
    def to_s
      msg = message ? "#{message}\n" : ''
      "#{msg}Status: #{status}\nStdout: #{stdout}\nStderr: #{stderr}"
    end
  }
end
