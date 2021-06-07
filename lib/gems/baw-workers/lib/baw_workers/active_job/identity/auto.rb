# frozen_string_literal: true
# # frozen_string_literal: true

# module BawWorkers
#   module ActiveJob
#     module Identity
#       # Default implementations for the BawWorkers::ActiveJob::Identity module.
#       module Auto
#         extend ActiveSupport::Concern

#         included do
#           raise TypeError, 'BawWorkers::ActiveJob::Identity must not be included'
#         end

#         prepended do
#           job_base_is_ancestor!
#         end

#         def name
#           "#{self.class.name}:#{job_id}"
#         end

#         def job_id
#           IdHelpers.generate_uuid
#         end
#       end
#     end
#   end
# end
