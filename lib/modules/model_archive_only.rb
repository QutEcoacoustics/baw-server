module ModelArchiveOnly
  extend ActiveSupport::Concern

  included do
    # add deleted_at and deleter_id
    acts_as_paranoid
    validates_as_paranoid

    before_destroy :prevent_destroy_for_archived, on: :delete
  end

  def self.archive_only?
    true
  end

  private

  def prevent_destroy_for_archived
    if self.respond_to?('deleted?'.to_sym) && self.deleted?
      fail CustomErrors::DeleteNotPermittedError.new("Cannot delete #{self.class.model_name.human}")
    end
  end


end