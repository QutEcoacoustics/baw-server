# frozen_string_literal: true

# Add a temporary logger that will log structured logs as JSON payloads
# to a in-memory buffer.
RSpec.shared_context 'with a logger spy' do
  let(:log_output) { StringIO.new }

  let(:appender) {
    SemanticLogger::Appender.factory(io: log_output, formatter: :json)
  }

  around do |example|
    SemanticLogger.add_appender(appender:)

    desired_level = example.metadata[:log_level]
    before_level = SemanticLogger.default_level
    SemanticLogger.default_level = desired_level if desired_level.present?
    example.call
  ensure
    SemanticLogger.remove_appender(appender)
    log_output.close
    SemanticLogger.default_level = before_level
  end

  def log_entries
    SemanticLogger.flush
    position = log_output.pos
    log_output.rewind
    log_output.readlines.map { |line| JSON.parse(line, { symbolize_names: true }) }
  ensure
    log_output.pos = position
  end

  def expect_log_entries_to_include(*expected)
    entries = log_entries
    aggregate_failures do
      expected.each do |entry|
        expect(entries).to match(a_collection_including(entry))
      end
    end
  end

  def expect_log_entries_to_not_include(*expected)
    entries = log_entries
    aggregate_failures do
      expected.each do |entry|
        expect(entries).not_to match(a_collection_including(entry))
      end
    end
  end
end
