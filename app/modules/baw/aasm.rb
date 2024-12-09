# frozen_string_literal: true

module Baw
  # Extensions for AASM.
  # https://github.com/aasm/aasm#inspection
  # Prepended in an initializer.
  module Aasm
    def current_state?(state)
      aasm.current_state == state.to_sym
    end

    def may_transition_to_state(state)
      state = state.to_sym unless state.is_a?(Symbol)

      aasm.states(permitted: true).map(&:name).include?(state)
    end

    def transition_to_state(state)
      state = state&.to_sym unless state.is_a?(Symbol)

      events = aasm.permitted_transitions.select { |pair|
        pair in { state: ^state }
      }

      if events.size != 1
        Rails.logger.debug(
          'Too many possible states', new_state: state, possible_events: events, self: self
        )

        raise NoTransitionAvailable.new(self, state, events.size)
      end

      events => [ { event: target_event } ]
      Rails.logger.debug(
        'Transitioning state machine', new_state: state, target_event:, self: self
      )

      public_send(target_event, state)
    end

    def restricted_fire(event, allowed_events: nil)
      event = event.to_sym unless event.is_a?(Symbol)

      known_events = aasm.events.map(&:name).to_set(&:to_sym)
      allowed_events = (allowed_events || []).to_set(&:to_sym)
      union = known_events & allowed_events

      raise ForbiddenTransition.new(self, event, allowed_events) unless union.include?(event)

      public_send(event)
    end

    class AasmError < RuntimeError
    end

    # Represents a failure to find a unique event that can be used to transition from one state to another.
    class NoTransitionAvailable < AasmError
      attr_reader :object, :target_state, :current_state, :events_found

      def initialize(object, target_state, events_found)
        @object = object
        @target_state = target_state
        @current_state = object.aasm.current_state
        @events_found = events_found

        super("Cannot transition from #{current_state} to #{target_state}, #{events_found} allowed transitions found")
      end
    end

    class ForbiddenTransition < AasmError
      attr_reader :object, :event, :allowed_events

      def initialize(object, event, allowed_events)
        @object = object
        @event = event
        @allowed_events = allowed_events

        allowed = allowed_events.map(&:to_s).join(', ')
        super("Transition #{event} is not allowed, allowed transitions are: #{allowed}")
      end
    end
  end
end
