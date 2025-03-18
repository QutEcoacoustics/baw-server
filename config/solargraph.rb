# frozen_string_literal: true

# Instructions: https://solargraph.org/guides/rails
# sourced from: https://gist.githubusercontent.com/castwide/28b349566a223dfb439a337aea29713e/raw/d1d4462b92f411b378d87a39482b830e012513bd/rails.rb

# The following comments fill some of the gaps in Solargraph's understanding of
# Rails apps. Since they're all in YARD, they get mapped in Solargraph but
# ignored at runtime.
#
# You can put this file anywhere in the project, as long as it gets included in
# the workspace maps. It's recommended that you keep it in a standalone file
# instead of pasting it into an existing one.
#
# @!parse
#   class ActionController::Base
#     include ActionController::MimeResponds
#     include ActionController::Parameters
#     include ActionController::StrongParameters
#     extend ActiveSupport::Callbacks::ClassMethods
#     extend AbstractController::Callbacks::ClassMethods
#   end
#   class ActiveRecord::Base
#     extend ActiveRecord::QueryMethods
#     extend ActiveRecord::FinderMethods
#     extend ActiveRecord::Associations::ClassMethods
#     include ActiveRecord::Persistence
#   end
#   class ActiveJob::Base
#     include ActiveJob::Core
#     include ActiveJob::QueueAdapter
#     include ActiveJob::QueueName
#     include ActiveJob::QueuePriority
#     include ActiveJob::Enqueuing
#     include ActiveJob::Execution
#     include ActiveJob::Callbacks
#     include ActiveJob::Exceptions
#     include ActiveJob::Instrumentation
#     include ActiveJob::Logging
#     include ActiveJob::Timezones
#     include ActiveJob::Translation
#   end
# @!override ActiveRecord::FinderMethods#find
#   @overload find(id)
#     @param id [Integer]
#     @return [self]
#   @overload find(list)
#     @param list [Array]
#     @return [Array<self>]
#   @overload find(*args)
#     @return [Array<self>]
#   @return [self, Array<self>]
