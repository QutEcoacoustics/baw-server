# frozen_string_literal: true

module BawApp
  # Strongly typed settings for the batch_analysis section of our config
  class BatchAnalysisSettings < ::Dry::Struct
    # Connection settings for the cluster
    class ConnectionSettings < ::Dry::Struct
      # @!attribute [r] host
      #   @return [String]
      attribute :host, ::BawApp::Types::String

      # @!attribute [r] port
      #   @return [Integer]
      attribute :port, ::BawApp::Types::Integer

      # @!attribute [r] username
      #   @return [String]
      attribute :username, ::BawApp::Types::String

      # @!attribute [r] password
      #   @return [String,nil]
      attribute :password, ::BawApp::Types::String.optional

      # @!attribute [r] key_file
      #   @return [Pathname,nil]
      attribute :key_file, ::BawApp::Types::PathExists.optional
    end

    # PBS settings for the cluster
    class PbsSettings < ::Dry::Struct
      # @!attribute [r] default_queue
      #   @return [String,nil]
      attribute :default_queue, ::BawApp::Types::String.optional

      # @!attribute [r] primary_group
      #   @return [String,nil]
      attribute :primary_group, ::BawApp::Types::String
    end

    # @!attribute [r] connection
    #   @return [::BawApp::BatchAnalysisSettings::ConnectionSettings]
    attribute :connection, ConnectionSettings

    # @!attribute [r] pbs
    #   @return [::BawApp::BatchAnalysisSettings::PbsSettings]
    attribute :pbs, PbsSettings

    # @!attribute [r] auth_tokens_expire_in
    #   @return [Integer]
    attribute :auth_tokens_expire_in, ::BawApp::Types::Integer.constrained(gt: 0)

    # @!attribute [r] remote_enqueue_limit
    #   @return [Integer,nil]
    attribute :remote_enqueue_limit, ::BawApp::Types::Integer.optional.constrained(gt: 0)

    # @!parse
    #   class RootDataPathMapping
    #     # @return [Pathname]
    #     attr_reader :workbench
    #     # @return [Pathname]
    #     attr_reader :cluster
    #   end
    # @!attribute [r] root_data_path_mapping
    #   @return [RootDataPathMapping]
    attribute :root_data_path_mapping do
      attribute :workbench, ::BawApp::Types::Pathname
      attribute :cluster, ::BawApp::Types::Pathname
    end
  end

  # Extensions the Config::Options class and hence also the Settings constant
  module SettingsModule
    # @return [::BawApp::BatchAnalysisSettings]
    def batch_analysis
      @batch_analysis ||= BatchAnalysisSettings.new(super)
    end
  end
end

# For go to definition support in IDE
# @!parse
#   class Settings
#     include BawApp::SettingsModule
#     extend BawApp::SettingsModule
#   end
