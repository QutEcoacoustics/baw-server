# frozen_string_literal: true

# TODO: I'm pretty sure there is a better way to do this?
module AasmHelpers
  def may_transition_to_state(state)
    events = events_for_transition_to_state(state)

    events.size == 1
  end

  def transition_to_state(state)
    events = events_for_transition_to_state(state)

    raise "Cannot transition to next state (#{events.size} possible events found)" if events.size != 1

    public_send(events[0].name, state)
  end

  def events_for_transition_to_state(state)
    # find the event in the state machine to fire
    aasm.events.find_all do |event|
      event.transitions_to_state?(state)
    end
  end
end
