class ExistenceValidator < ActiveModel::EachValidator

  # Required for Rails 4.2
  def initialize(options={})
    super
    options[:class].send :attr_accessor, :custom_attribute
  end

# http://www.samuelmullen.com/2013/12/validating-presence-of-associations-and-foreign-keys-in-rails/
  def validate_each(record, attribute, value)
    if value.blank? && record.send("#{attribute}_id".to_sym).blank?
      record.errors[attribute] << I18n.t('errors.messages.existence', record: record.class.to_s)
    end
  end
end