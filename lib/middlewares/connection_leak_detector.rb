# frozen_string_literal: true

# adapted from https://medium.com/@mendespedro77/solving-activerecord-connection-pool-errors-in-rails-applications-b7a5861573b9
class ConnectionLeakDetector
  def initialize(app)
    @app = app
  end

  def call(env)
    log_connection_pool_stats if BawApp.log_connection_pool_stats?
    status, headers, body = @app.call(env)
    [status, headers, body]
  end

  private

  def log_connection_pool_stats
    pool = ActiveRecord::Base.connection_pool
    stats = pool.stat
    Rails.logger.info("Connection Pool Stats #{stats.inspect}")

    pool.connections.each_with_index do |connection, index|
      Rails.logger.warn(
        "Open Connection #{index}",
        active: connection.active?,
        connected: connection.connected?,
        owner: connection.owner.present? ? connection.owner.inspect : '[UNUSED]',
        current_thread: Thread.current.inspect
      )
      connection.try(:query_history).each do |query|
        Rails.logger.warn(
          "Last 10 queries for connection #{index}",
          **query
        )
      end
    end
  end

  module QueryHistory
    attr_reader :query_history

    def log(*args, **keyword_args, &)
      if BawApp.log_connection_pool_stats?
        @query_history ||= []
        @query_history << { args: args, keyword_args: keyword_args }
        @query_history.shift if @query_history.size > 10
      end

      super
    end
  end
  ::ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(QueryHistory)
end
