# frozen_string_literal: true

# from http://dev.mensfeld.pl/2013/05/paperclip-bootstrap-and-simpleform-working-together-on-rails/

module PaperclipExtensions
  extend ActiveSupport::Concern

  module ClassMethods
    # Changes the default Paperclip behaviour so all the errors from attachments
    # are assigned to an attachment name field instead of 4 different once
    # This allows us to use Bootstrap and SimpleForm without any other extra
    # code
    def has_attached_file(name, options = {})
      # Initialize Paperclip stuff
      super
      # Then create a hookup to rewrite all the errors after validation
      after_validation do
        errors[name] ||= []
        ['file_name', 'file_size', 'content_type', 'updated_at'].each do |field|
          field_errors = errors["#{name}_#{field}"]
          next if field_errors.blank?

          errors[name] += field_errors
          field_errors.clear
        end
        errors[name].flatten!
      end
    end
  end
end

ActiveRecord::Base.include PaperclipExtensions
