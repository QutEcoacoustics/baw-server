# frozen_string_literal: true

class AddContactableToUsers < ActiveRecord::Migration[7.2]
  def change
    create_enum :consent, ['unasked', 'yes', 'no']
    add_column :users, :contactable, :enum, enum_type: :consent, default: 'unasked', null: false,
      comment: 'Is the user contactable for email communications'
  end
end
