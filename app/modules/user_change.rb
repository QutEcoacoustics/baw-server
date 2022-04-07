# frozen_string_literal: true

module UserChange
  extend ActiveSupport::Concern

  included do
    before_validation :set_creator_id, on: :create
    before_validation :set_updater_id, on: :update
    before_validation :set_deleter_id, on: :delete
  end

  private

  def set_creator_id
    self.creator_id = User.stamper if respond_to?(:creator_id=) && creator_id.blank?
  end

  def set_updater_id
    self.updater_id = User.stamper if respond_to?(:updater_id=)
  end

  def set_deleter_id
    self.deleter_id = User.stamper if respond_to?(:deleter_id=) && deleter_id.blank?
  end
end
