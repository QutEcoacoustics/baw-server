# frozen_string_literal: true

module Client
  # Generate external URLs
  class Routes
    # https://www.rfc-editor.org/rfc/rfc6570.txt
    BASE = '{protocol}://{host}{+port}'.freeze
    CLIENT_HOME = Addressable::Template.new("#{BASE}/")
    ANALYSIS_JOBS = Addressable::Template.new("#{BASE}/projects/{project}/analysis_jobs/{id}")
    SYSTEM_ANALYSIS_JOBS = Addressable::Template.new("#{BASE}/admin/analysis_jobs/{id}")
    # LISTEN = Addressable::Template.new("#{BASE}/listen/{value}{?start,end}")

    # @param [String] host
    # @param [Integer, nil] port
    # @param [String] protocol
    # @return [Client::Routes]
    def initialize(host:, port: nil, protocol: 'http')
      @host = host
      @port = port.present? ? ":#{port}" : ''
      @protocol = protocol
    end

    def home_url = expand(CLIENT_HOME)

    # @param [AnalysisJob] analysis_job
    def analysis_job_url(analysis_job)
      if analysis_job.project_id.present?
        expand(ANALYSIS_JOBS, project: analysis_job.project_id, id: analysis_job.id)
      else
        expand(SYSTEM_ANALYSIS_JOBS, id: analysis_job.id)
      end
    end

    # # @param value an AudioRecording id
    # def listen_url(value = nil, start_offset_sec = nil, end_offset_sec = nil)
    #   expand(LISTEN, value: value, start: start_offset_sec, end: end_offset_sec)
    # end

    private

    def expand(template, **)
      template.expand(protocol: @protocol, host: @host, port: @port, **)
    end
  end
end
