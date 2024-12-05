# frozen_string_literal: true

# Sets current values for the current model.
module SetCurrent
  extend ActiveSupport::Concern

  included do
    before_action :set_current
  end

  private

  def set_current
    Current.user = current_user
    Current.ability = current_ability
    Current.action_name = action_name
    Current.path = request.env['PATH_INFO']
    Current.method = request.method
  end
end
