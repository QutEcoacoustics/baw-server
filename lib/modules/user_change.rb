module UserChange
  extend ActiveSupport::Concern

  included do
    before_validation :set_creator_id, on: :create if respond_to?(:creator_id)
    before_validation :set_updater_id, on: :update if respond_to?(:updater_id)
    before_validation :set_deleter_id, on: :delete if respond_to?(:deleter_id)
  end

  private

  def set_creator_id
    if respond_to?(:creator_id)
      self.creator_id = User.stamper
    end
  end

  def set_updater_id
    if respond_to?(:updater_id)
      self.updater_id = User.stamper
    end
  end

  def set_deleter_id
    if respond_to?(:deleter_id)
      self.deleter_id = User.stamper
    end
  end

end