# frozen_string_literal: true

# Records invocation counts of controller actions.
# Uses Rails' own instrumentation.
# It's a handy way to create basic spies (without the complexity of real spies).
# This method also works for concurrent, asynchronous, and multi-worker invocations - which a spy would not work for.
module ControllerWatcher
  NAMESPACE = 'baw:test:controller_watcher:'

  def self.increment(name)
    BawWorkers::Config.redis_communicator.redis.incr(
      NAMESPACE + name
    )
  end

  def self.count(name)
    BawWorkers::Config.redis_communicator.redis.get(
      NAMESPACE + name
    ).to_i
  end

  def self.reset(name)
    BawWorkers::Config.redis_communicator.redis.del(
      NAMESPACE + name
    )
  end

  def self.validate(controller, action)
    raise unless controller.is_a?(Class)
    raise unless controller.ancestors.include?(ActionController::Base)
    raise unless action.is_a?(Symbol)

    make_name(controller.name, action)
  end

  def self.make_name(controller_name, action)
    "#{controller_name}##{action}"
  end

  module ExampleGroup
    def watch_controller(klass)
      raise unless klass.is_a?(Class)
      raise unless klass.ancestors.include?(ActionController::Base)

      target_name = klass.name

      around do |example|
        subscriber = ActiveSupport::Notifications.subscribe(/process_action.action_controller/) { |event|
          controller_name = event.payload[:controller]

          next unless controller_name == target_name

          action = event.payload[:action]
          key = ControllerWatcher.make_name(controller_name, action)
          ControllerWatcher.increment(key)
        }

        example.run

        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end
  end

  module Example
    def controller_invocation_count(controller, action)
      key = ControllerWatcher.validate(controller, action)

      ControllerWatcher.count(key)
    end

    def reset_controller_invocation_count(controller, action)
      key = ControllerWatcher.validate(controller, action)

      ControllerWatcher.reset(key)
    end

    def wait_for_action_invocation(controller, action, goal: 1, timeout: 10)
      key = ControllerWatcher.validate(controller, action)
      start = controller_invocation_count(controller, action)
      current = start
      logger = SemanticLogger[ControllerWatcher]
      logger.warn("Starting to wait for #{key} to be set", goal:, current:, start:)

      result = false
      (timeout * 10).times do |i|
        current = controller_invocation_count(controller, action)

        if current >= goal
          logger.warn("Finished waiting for #{key}", attempt: i, goal:, current:, start:)
          result = true
          break
        end

        logger.warn("Waiting for #{key} to be set", attempt: i, goal:, current:, start:)

        sleep 0.1
      end

      return if result

      raise "Controller invocation count not reached. Last value: #{current}"
    end
  end
end
