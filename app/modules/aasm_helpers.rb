# frozen_string_literal: true

# Extensions for AASM.
# https://github.com/aasm/aasm#inspection
module AasmHelpers
  def may_transition_to_state(state)
    state = state.to_sym unless state.is_a?(Symbol)

    aasm.states(permitted: true).map(&:name).include?(state)
  end

  def transition_to_state!(state)
    state = state.to_sym unless state.is_a?(Symbol)

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

  # Represents a failure to find a unique event that can be used to transition from one state to another.
  class NoTransitionAvailable < RuntimeError
    attr_reader :object, :target_state, :current_state, :events_found

    def initialize(object, target_state, events_found)
      @object = object
      @target_state = target_state
      @current_state = object.aasm.current_state
      @events_found = events_found

      super("Cannot transition from #{current_state} to #{target_state}, #{events_found} allowed transitions found")
    end
  end
end
