# frozen_string_literal: true

# Sets current values for the current model.
module SetCurrent
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    before_action :set_current_ability
  end

  private

  def set_current_user
    Current.user = current_user
  end

  def set_current_ability
    Current.ability = current_ability
  end
end
