# frozen_string_literal: true

module PBS
  # limits are checked one by one, is order of
  #  - queue, then server interleaved with each class
  #  - group, project, all, user
  # Example:
  #   Server pbs
  #       max_queued = [u:PBS_GENERIC=20]
  #       max_queued = [o:PBS_ALL=50]
  #       max_queued = [g:PBS_GENERIC=40]
  #       max_queued = [p:PBS_GENERIC=30]
  #       max_queued = [u:user123=5]
  #       max_queued = [u:"user with spaces"=15]
  #       max_queued = [g:groupname=10]
  #       max_queued = [g:'group with spaces'=12]
  #       max_queued = [p:projectname=25]
  #       max_queued = [u:banned_user=0]
  module Limits
    USER_CLASS = 'u'
    GROUP_CLASS = 'g'
    PROJECT_CLASS = 'p'
    ALL_CLASS = 'o'

    PBS_ALL = 'PBS_ALL'
    PBS_GENERIC = 'PBS_GENERIC'

    MODE_SERVER = 'Server'
    MODE_QUEUE = 'Queue'

    LIMIT_REGEX = /^\s*(?<key>\w+)\s*=\s*\[(?<type>\w):\s*['"]?(?<name>.+?)['"]?\s*=\s*(?<value>\w+)\s*\]$/
    MODE_REGEX = /^(?<mode>#{MODE_SERVER}|#{MODE_QUEUE})\s+(?<name>.+)$/

    ServerOrQueue = Data.define(:type, :name) {
      def initialize(type:, name:)
        case type
        when 'Server'
          :server
        when 'Queue'
          :queue
        else
          raise ArgumentError, "Invalid type: #{type}. Must be 'Server' or 'Queue'."
        end => type
        raise ArgumentError, 'Name must be a String' unless name.is_a?(String)

        super
      end

      def server?
        type == :server
      end

      def queue?
        type == :queue
      end

      def <=>(other)
        return nil unless other.is_a?(ServerOrQueue)

        # queue should be less than server
        return -1 if server? && other.queue?
        return 1 if queue? && other.server?

        # otherwise compare by name
        name <=> other.name
      end
    }

    Limit = Data.define(:target, :type, :name, :value) {
      def initialize(target:, type:, name:, value:)
        raise ArgumentError, 'Limit target must be a ServerOrQueue' unless target.is_a?(ServerOrQueue)
        raise ArgumentError, 'Limit types must be one of: u, g, p, o' unless [USER_CLASS, GROUP_CLASS, PROJECT_CLASS,
                                                                              ALL_CLASS].include?(type)
        raise ArgumentError, 'Limit name must be a String' unless name.is_a?(String)

        raise ArgumentError, "Limit name for type 'o' must be '#{PBS_ALL}'" if type == ALL_CLASS && name != PBS_ALL

        numerical = Integer(value, 10, exception: false)

        # 🚨DODGY ALERT:🚨 value can include suffixes like 'k' for thousands, or 'mb' for megabytes.
        # We don't need to parse that at this time.
        raise ArgumentError, "Limit value `#{value}` must be an Integer" if numerical.nil?

        super(target:, type:, name:, value: numerical)
      end

      def user?
        type == USER_CLASS
      end

      def group?
        type == GROUP_CLASS
      end

      def project?
        type == PROJECT_CLASS
      end

      def all?
        type == ALL_CLASS
      end

      def pbs_all?
        name == PBS_ALL
      end

      def pbs_generic?
        name == PBS_GENERIC
      end

      def type_order
        case type
        when GROUP_CLASS
          0
        when PROJECT_CLASS
          1
        when ALL_CLASS
          2
        when USER_CLASS
          3
        else
          raise 'Invalid limit type'
        end
      end

      def <=>(other)
        return nil unless other.is_a?(Limit)

        [name, target, type_order] <=> [other.name, other.target, other.type_order]
      end
    }

    module_function

    # Parses a qmgr limit list.
    # @param lines [Array<String>] the lines to parse
    # @param search_key [String] the key to search for
    # @param current_user [String] the current user
    # @param current_group [String] the current group
    # @param current_project [String] the current project
    # @return [Integer,nil] the limit value, or nil if not set
    def parse_qmgr_limit_list(lines, search_key, current_user, current_group, current_project)
      target = nil
      limits = []

      lines.split("\n").each do |line|
        trimmed = line.strip
        MODE_REGEX.match(trimmed) do |match|
          target = ServerOrQueue.new(type: match[:mode], name: match[:name])
          next
        end

        next if trimmed.blank? || trimmed.start_with?('#')

        # now parse the limit line
        LIMIT_REGEX.match(trimmed) do |match|
          raise 'Target must be set before parsing limits' if target.nil?

          key = match[:key]

          # don't bother keeping the limit unless it is the one we care about
          next unless key == search_key

          limit = Limit.new(
            target: target,
            type: match[:type],
            name: match[:name].strip,
            value: match[:value]
          )

          # don't bother keeping the limit if it doesn't affect our user, group, or project
          # (for the generic and all limits, we keep them regardless of the user, group, or project)
          unless limit.pbs_all? || limit.pbs_generic?
            next if limit.user? && limit.name != current_user
            next if limit.group? && limit.name != current_group
            next if limit.project? && limit.name != current_project
          end

          limits << limit
        end
      end

      # sort the limits by target, then type, then name
      limits.sort!
    end
  end
end
