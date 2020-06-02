# frozen_string_literal: true

# A monkey patch for resque status

module Resque
  module Plugins
    module Status
      EXPIRE_STATUSES = [
        Resque::Plugins::Status::STATUS_COMPLETED,
        Resque::Plugins::Status::STATUS_FAILED,
        Resque::Plugins::Status::STATUS_KILLED
      ].freeze

      class Hash
        # set a status by UUID. <tt>messages</tt> can be any number of strings or hashes
        # that are merged in order to create a single status.
        # WARNING: MONKEY PATCH
        # https://github.com/quirkey/resque-status/blob/11eb130ad1bc9cbc11aae3bad4d507ee06f5bb0a/lib/resque/plugins/status/hash.rb
        # Now only sets a TTL IFF status is in the expire list. Thus the status key
        # has no expire until it has completed/failed/killed.
        def self.set(uuid, *messages)
          val = Resque::Plugins::Status::Hash.new(uuid, *messages)
          redis.set(status_key(uuid), encode(val))

          # only set the TTL if the job has finished
          redis.expire(status_key(uuid), expire_in) if expire_in && EXPIRE_STATUSES.include?(val['status'])

          val
        end
      end
    end
  end
end
