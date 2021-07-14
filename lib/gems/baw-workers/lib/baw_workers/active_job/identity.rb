# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    # A module that ensures an ActiveJob implements a name and job_id
    module Identity
      extend ActiveSupport::Concern
      # @!parse
      #   extend ClassMethods
      #   extend ActiveSupport::Concern
      #   include ::ActiveJob::Base
      #   include ::ActiveJob::Core
      #   include ::ActiveJob::Logger

      included do
        raise TypeError, 'BawWorkers::ActiveJob::Identity must not be included. Try prepending.'
      end

      prepended do
        job_base_is_ancestor!
        job_base_has_method!
      end

      # ::nodoc::
      module ClassMethods
        private

        def job_base_has_method!
          return if ::ActiveJob::Enqueuing.method_defined?(:enqueue)

          raise TypeError,
                '::ActiveJob::Enqueuing no longer has method enqueue. Our hook will fail.'
        end

        def job_base_is_ancestor!
          return if ancestors.include?(::ActiveJob::Base)

          raise TypeError,
                "must be prepended in ActiveJob::Base. Actually is #{self}"
        end
      end

      # Produces a sensible friendly name for this payload, shown in UIs.
      # Must be inferred from serialized job parameters or else won't be shown
      # properly in remote jobs.
      # Should be unique but does not need to be. Has no operational effect.
      # Abstract, your job should override.
      # @return [String]
      def name
        application_job_overrides_method!(__method__)

        # default implementation for framework jobs
        job_id
      end

      # Job ID for this job. Overrides ActiveJob::Base::job_id
      # @return [String]
      attr_reader :job_id

      #
      # Job ID for this job.
      #
      # @param [String] value the new job_id
      #
      # @return [String] the set job id
      #
      def job_id=(value)
        @job_id = value.to_s
      end

      # Optionally produces a unique key to ensure uniqueness of this job.
      # See the Generators module methods for example job_id generators you can use.
      def create_job_id
        application_job_overrides_method!(__method__)

        # default implementation for framework jobs
        Generators.generate_uuid(self)
      end

      # This is our hook into ActiveJob::Base.
      # we hook like this to make sure we modify the job_id as soon on as possible,
      # before any callbacks get the chance to use it.
      # https://github.com/rails/rails/blob/58b46e9440f3460e93b8164205614e3ab85784da/activejob/lib/active_job/enqueuing.rb#L59
      def initialize(...)
        super(...)

        # there's no point making a job id on deserialization
        # deserialize creates the instance without assigning anything,
        # https://github.com/rails/rails/blob/58b46e9440f3460e93b8164205614e3ab85784da/activejob/lib/active_job/core.rb#L61
        return if @arguments.nil?

        # otherwise we assume we were called by `perform`
        # finally, the magic!
        new_id = create_job_id

        # spaces in particular mess with redis
        self.job_id = new_id.gsub(' ', '')
      end

      #
      # Test if this job has a module named `/ApplicationJob/` in it's ancestors.
      #
      # @return [Module,nil] the matched class if found, or else nil
      #
      def application_job_class
        @application_job_class ||= self.class.ancestors.find { |ancestor|
          ancestor.name =~ /ApplicationJob/
        }
      end

      def application_job_overrides_method!(name)
        return if application_job_class.nil?

        raise NotImplementedError, "You must implement #{name} in your job class."
      end
    end
  end
end
