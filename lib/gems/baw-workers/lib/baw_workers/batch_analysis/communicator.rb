# frozen_string_literal: true

module BawWorkers
  module BatchAnalysis
    # Starts analyses on a compute cluster.
    class Communicator
      # @return [PBS::Connection]
      attr_reader :connection

      def initialize
        @connection = PBS::Connection.new(Settings.batch_analysis)
      end

      # Run a script on an audio recording for a system job (no associated analysis job)
      # @param analysis_job [AnalysisJob] the script execute
      # @param audio_recording [AudioRecording]
      def run_system_script(_analysis_job, _audio_recording)
        connection.submit_job(
          script.executable_command
        )
      end
    end
  end
end
