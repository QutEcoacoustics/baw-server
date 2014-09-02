module UserChange
  extend ActiveSupport::Concern

  included do
    before_validation :set_creator_id, on: :create
    before_validation :set_updater_id, on: :update
    before_validation :set_deleter_id, on: :delete
  end

  private

  def set_creator_id
    if respond_to?('creator_id='.to_sym) && self.creator_id.blank?
      self.creator_id= User.stamper
    end
  end

  def set_updater_id
    if respond_to?('updater_id='.to_sym) && self.updater_id.blank?
      self.updater_id= User.stamper
    end
  end

  def set_deleter_id
    if respond_to?('deleter_id='.to_sym) && self.deleter_id.blank?
      self.deleter_id= User.stamper
    end
  end

end