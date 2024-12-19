# frozen_string_literal: true

module BawApp
  # forces all log messages into a lower level inspired by
  # https://github.com/reidmorrison/semantic_logger/blob/v4.9.0/lib/semantic_logger/debug_as_trace_logger.rb
  class SuppressedLevelLogger < ::SemanticLogger::Logger
    def initialize(*args, **kwargs, &)
      split_level = kwargs.delete(:split_level)

      raise ArgumentError, '`split_level` must be a symbol' unless split_level.is_a?(Symbol)

      @split = ::SemanticLogger::Levels.index(split_level)
      super
    end

    def mutate_level(index)
      new_index = index <= @split && index.positive? ? index - 1 : index
      new_level = ::SemanticLogger::Levels.level(new_index)
      [new_index, new_level]
    end

    # For things that expect a logger to behave like a standard ruby logger
    # adapted from:
    # https://github.com/reidmorrison/semantic_logger/blob/05a00e186c958ddd474285a37aa7e910aa5e9841/lib/semantic_logger/concerns/compatibility.rb#L40
    def add(severity, message = nil, progname = nil, &)
      # convert a logger severity into a semantic logger level
      index = SemanticLogger::Levels.index(severity)

      # mutate the index
      index, level = mutate_level(index)

      if level_index <= index
        log_internal(level, index, message, progname, &)
        true
      else
        false
      end
    end

    SemanticLogger::Levels::LEVELS.each_with_index do |level, index|
      class_eval <<~METHODS, __FILE__, __LINE__ + 1
        def #{level}(message=nil, payload=nil, exception=nil, &block)
          index, level = mutate_level(#{index})

          if level_index <= index
            log_internal(level, index, message, payload, exception, &block)
            true
          else
            false
          end
        end

        def #{level}?
          index, _ = mutate_level(#{index})
          level_index <= index
        end

        def measure_#{level}(message, params = {}, &block)
          index, level = mutate_level(#{index})
          if level_index <= index
            measure_internal(level, index, message, params, &block)
          else
            block.call(params) if block
          end
        end

        def benchmark_#{level}(message, params = {}, &block)
          index, level = mutate_level(#{index})
          if level_index <= index
            measure_internal(level, index, message, params, &block)
          else
            block.call(params) if block
          end
        end
      METHODS
    end
  end
end
