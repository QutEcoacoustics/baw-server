class DeviseCreateUsers < ActiveRecord::Migration
  def change
    create_table(:users) do |t|
      ## Database authenticatable
      t.string :email, null: false, default: '', limit: 255
      t.string :user_name, null: false, default: '', limit: 255
      t.string :encrypted_password, null: false, default: '', limit: 255

      ## Recoverable
      t.string   :reset_password_token, limit: 255
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, :default => 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip, limit: 255
      t.string   :last_sign_in_ip, limit: 255

      ## Confirmable
      t.string   :confirmation_token, limit: 255
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email, limit: 255 # Only if using reconfirmable

      ## Lockable
      t.integer  :failed_attempts, :default => 0 # Only if lock strategy is :failed_attempts
      t.string   :unlock_token, limit: 255 # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      ## Token authenticatable
      t.string :authentication_token, limit: 255

      ## Invitable
      t.string :invitation_token, limit: 255

      t.timestamps null: true
    end

    add_index :users, :email, unique: true
    # add_index :users, :reset_password_token, :unique => true
    add_index :users, :confirmation_token, unique: true
    # add_index :users, :unlock_token,         :unique => true
    add_index :users, :authentication_token, unique: true
  end
end
