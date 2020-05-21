
# special requires because file naming does not match zeitwerk's expected naming
module Resque
  require_relative 'resque_api'
  require_relative 'resque_job_id'
  require_relative 'resque_status_custom_expire'

end
