# frozen_string_literal: true

module Emu
  # Used to fix audio files with metadata errors.
  module Fix
    include SemanticLogger::Loggable

    module_function

    BAR_LT_DURATION_BUG = 'FL010'

    STATUS_FIXED = 'Fixed'
    STATUS_NOOP = 'NoOperation'
    STATUS_AFFECTED = 'Affected'

    CHECK_STATUS_AFFECTED = 'Affected'
    CHECK_STATUS_UNAFFECTED = 'Unaffected'
    CHECK_STATUS_NOT_APPLICABLE = 'NotApplicable'
    CHECK_STATUS_REPAIRED = 'Repaired'
    CHECK_STATUS_ERROR = 'Error'

    #
    # Check if a fix is needed
    #
    # @param [Pathname] path the path to operate on
    # @param [String] the fix id for the fix operation to apply
    #
    # @return [ExecuteResult] The result from executing the emu command.
    #
    def check(path, fix)
      Emu.execute('fix', 'check', path, '--fix', fix)
    end

    # @param [Pathname] path the path to operate on
    # @param [String] the fix id for the fix operation to apply
    # @return [ExecuteResult] The result from executing the emu command.
    def apply(path, fix)
      Emu.execute('fix', 'apply', path, '--fix', fix)
    end

    # @return [Array<Hash>] The result from executing the emu command.
    def list
      result = Emu.execute('fix', 'list')

      return result.records if result.success?

      nil
    end

    # @param [Pathname] path the path to operate on
    # @param fix [String] the fix id for the fix operation to apply
    # @return [ExecuteResult] The result from executing the emu command.
    def fix_if_needed(path, fix)
      logger.tagged(fix:, path:) do
        raise ArgumentError, 'path must exist and be pathname' unless path.is_a?(Pathname) && path.exist?

        check_result = nil
        logger.measure_debug('checking if fix needed') do
          check_result = check(path, fix)
        end

        logger.debug('status of file is', record:  check_result.records.first)

        return check_result unless check_result.success?

        return check_result unless check_result.records.first[:problems][fix][:status] == STATUS_AFFECTED

        logger.measure_debug('applying fix') do
          return apply(path, fix)
        end
      end
    end
  end
end
