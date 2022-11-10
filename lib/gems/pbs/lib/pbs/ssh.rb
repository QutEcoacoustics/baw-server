# frozen_string_literal: true

module PBS
  # Controls the SSH transport for the connection to PBS
  #
  # THESE METHODS ARE NOT SAFE AGAINST INJECTION ATTACKS.
  # DO NOT pass in user controlled strings!
  module SSH
    include Dry::Monads[:result]

    class TransportError < StandardError; end

    # forces all log messages into a debug level inspired by
    # https://github.com/reidmorrison/semantic_logger/blob/v4.9.0/lib/semantic_logger/debug_as_trace_logger.rb
    class InfoAsDebugLogger < ::SemanticLogger::Logger
      def log_internal(level, *args, **keyword_args, &)
        return super(:debug, *args, **keyword_args, &) if level == :info

        super
      end
    end

    private

    # @return [BawApp::BatchAnalysisSettings]
    attr_reader :settings

    # @return [::SemanticLogger::Logger]
    def ssh_logger
      @ssh_logger ||= SemanticLogger[PBS::SSH]
    end

    # @return [InfoAsDebugLogger]
    def net_ssh_logger
      @net_ssh_logger ||= InfoAsDebugLogger.new(Net::SSH.name)
    end

    # @return [String]
    def key_file
      @key_file ||= settings.connection.key_file&.read
    end

    # Execute a command
    # @param command [String]
    # @return [Array((Integer,nil),String,String)] status, stdout, stderr
    def execute(command)
      stdout = ''
      stderr = ''
      status = {}
      ssh_logger.measure_debug('execute ssh command', payload: { command: }) do
        connection.exec!(command, status:) do |_channel, stream, data|
          stdout += data if stream == :stdout
          stderr += data if stream == :stderr
        end
      rescue Net::SSH::Exception, Errno::ECONNREFUSED => e
        raise TransportError, e.message
      end

      exit_code = status.fetch(:exit_code, nil)

      ssh_logger.log(
        exit_code&.zero? ? :debug : :error,
        command:, exit_code:, stdout:, stderr:
      )

      [exit_code, stdout, stderr]
    end

    # Execute a command
    # @param command [String] the shell command to execute
    # @param fail_message [String] a message to add to the failure if the command fails
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def execute_safe(command, fail_message: '')
      status, stdout, stderr = execute(command)

      unless status&.zero?
        fail_message = fail_message.blank? ? '' : " when #{fail_message}"
        return Failure("Command failed with status `#{status}`#{fail_message}: \n#{stdout}\n#{stderr}")
      end

      Success([stdout, stderr])
    end

    # Upload a file to the remote. Intended for use with small files.
    # @param file [::StringIO] the file to upload
    # @param destination [Pathname] the path to upload the file
    # @return [::Dry::Monads::Result<nil>]
    def upload_file(file, destination:)
      raise ArgumentError, 'file must be a StringIO' unless file.is_a?(::StringIO)
      raise ArgumentError, 'destination is not a Pathname' unless destination.is_a?(Pathname)

      mkdir_result = remote_mkdir(destination.dirname)
      return mkdir_result if mkdir_result.failure?

      # http://net-ssh.github.io/net-scp/classes/Net/SCP.html
      ssh_logger.measure_info('Uploaded file', size: file.length, destination:) do
        connection.scp.upload!(file, destination.to_s) do |_ch, _name, sent, total|
          ssh_logger.debug("Uploading file #{destination.basename}: #{sent}/#{total}")
        end
      end

      Success(nil)
    rescue ::Net::SCP::Error => e
      Failure(e)
    end

    # Upload a file to the remote. Intended for use with small files.
    # @param destination [Pathname] the path to upload the file
    # @return [::Dry::Monads::Result<::StringIO>]  the file to download
    def download_file(path)
      raise ArgumentError, 'path is not a Pathname' unless path.is_a?(Pathname)

      mkdir_result = remote_mkdir(path.dirname)
      return mkdir_result if mkdir_result.failure?

      # http://net-ssh.github.io/net-scp/classes/Net/SCP.html
      ssh_logger.measure_info('Downloaded file', path:) do
        connection.scp.download!(path.to_s) do |_ch, _name, sent, total|
          ssh_logger.debug("Downloading file #{path.basename}: #{sent}/#{total}")
        end
      end => file

      Success(file)
    rescue ::Net::SCP::Error => e
      Failure(e)
    end

    # @param path [Pathname] the path to check for
    # @return [Boolean]
    def remote_exist?(path)
      raise ArgumentError, 'path is not a Pathname' unless path.is_a?(Pathname)

      status, _stdout, _stderr = execute("stat #{path}")

      status&.zero?
    end

    # @param dir [Pathname] the path to create for
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def remote_mkdir(dir)
      raise ArgumentError, 'dir is not a Pathname' unless dir.is_a?(Pathname)

      execute_safe("mkdir -p #{dir}", fail_message: 'creating remote directory')
    end

    # @param path [Pathname] the path to check for
    # @param permissions [String] a chmod permissions string
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def remote_chmod(path, permissions)
      raise ArgumentError, 'path is not a Pathname' unless path.is_a?(Pathname)

      execute_safe("chmod #{permissions} '#{path}'")
    end

    # @param path [Pathname] the path to delete
    # @return [::Dry::Monads::Result<Array(String,String)>] stdout, stderr
    def remote_delete(path, recurse: false)
      raise ArgumentError, 'path is not a Pathname' unless path.is_a?(Pathname)

      args = recurse ? ' -rf ' : ''
      execute_safe("rm #{args}'#{path}'")
    end

    # Returns an active connection.
    # Connections are cached and should keep alive for 900 seconds
    # @return [Net::SSH::Connection::Session]
    def connection
      return @connection unless @connection.nil? || @connection.closed?

      ssh_logger.debug(
        'establishing connection',
        host: settings.connection.host,
        username: settings.connection.username,
        port: settings.connection.port
      )

      @connection = Net::SSH.start(
        settings.connection.host,
        settings.connection.username,
        # https://github.com/net-ssh/net-ssh/blob/0150d054f0cd0beacd4ba1000c6df6d8636a2c18/lib/net/ssh/config.rb#L52
        auth_methods: ['publickey', 'password'],
        # we assume we always have a safe connection - this is meant to be an internal connection
        check_host_ip: false,
        # do not read any config from system config files
        config: false,
        # set to true to send a keepalive packet to the SSH server when there's no traffic between the SSH server and
        # Net::SSH client for the keepalive_interval seconds. Defaults to false.
        keepalive: true,
        # the interval seconds for keepalive. Defaults to 300 seconds.
        keepalive_interval: 300,
        # the maximum number of keepalive packet miss allowed. Defaults to 3
        keepalive_maxcount: 3,
        key_data: Array(key_file),
        # we need to define a separate instance of the logger here because
        # net-ssh mutates the level
        logger: net_ssh_logger,
        non_interactive: true,
        password: settings.connection.password,
        port: settings.connection.port,
        timeout: 10,
        # do not read from ssh-agent
        use_agent: false,
        verbose: BawApp.log_level
      )

      @connection
    end
  end
end
