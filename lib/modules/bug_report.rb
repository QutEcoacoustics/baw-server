class BugReport
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :name, :email, :description, :content, :recaptcha

  validates_format_of :email, with: /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, allow_blank: true, allow_nil: true
  validates_presence_of :description
  validates_length_of :description, maximum: 2000
  validates_presence_of :content
  validates_length_of :content, maximum: 5000

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end
end
