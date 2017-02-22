module ModelArchive
  extend ActiveSupport::Concern

  included do
    # enable archiving
    acts_as_paranoid
    validates_as_paranoid

    before_destroy :prevent_destroy_for_archived, on: :delete
  end

  private

  def prevent_destroy_for_archived
    # NOTE: for an admin to be able to delete an item
    # this 'self.deleted?' check will need to be disabled.
    if self.respond_to?('deleted?'.to_sym) && self.deleted?
      fail CustomErrors::DeleteNotPermittedError.new("Cannot delete #{self.class.model_name.human}")
    end
  end


end