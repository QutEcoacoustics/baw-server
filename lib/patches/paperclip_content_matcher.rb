# fix bug in paperclip content_type matcher
require 'paperclip'
module Paperclip
  module Shoulda
    module Matchers
      class ValidateAttachmentContentTypeMatcher

        def matches? subject
          @subject = subject
          @subject = @subject.new if @subject.class == Class
          allowed_types_allowed = allowed_types_allowed?
          rejected_types_rejected = rejected_types_rejected?

          @allowed_types && @rejected_types && allowed_types_allowed && rejected_types_rejected
        end

        protected

        def type_allowed?(type)
          @subject.send("#@attachment_name_content_type=", type)
          @subject.valid?
          @subject.errors[:"#@attachment_name_content_type"].blank? &&
              @subject.errors[:"#@attachment_name"].blank?
        end
      end
    end
  end
end