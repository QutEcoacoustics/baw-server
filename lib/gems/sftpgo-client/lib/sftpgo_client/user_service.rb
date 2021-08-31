# frozen_string_literal: true

module SftpgoClient
  module UserService
    include SftpgoClient::Validation

    SORT_ASCENDING = 'ASC'
    SORT_DESCENDING = 'DESC'
    MAXIMUM_LIMIT = 500

    USERS_PATH = 'users'

    # Returns an array with one or more users
    # For security reasons hashed passwords are omitted in the response
    # @param [Integer] offset  (default to 0)
    # @param [Integer] limit The maximum number of items to return. Max value is 500, default is 100 (default to 100)
    # @param [String] order Ordering users by username. Default ASC
    # @param [String] username Filter by username, exact match case sensitive
    # @param [Dry::Monads::Result<Array<SftpgoClient::User>>]
    def get_users(offset: nil, limit: nil, order: nil, username: nil)
      params = {}

      add_to_params(params, :offset, offset, &:natural_number?)
      add_to_params(params, :limit, limit, &method(:between_1_and_500))
      add_to_params(params, :order, order, &method(:valid_order))
      add_to_params(params, :username, username, &:string?)

      wrap_response(@connection.get(USERS_PATH, params)).fmap { |r|
        r.body.map(&SftpgoClient::User.method(:new))
      }
    end

    # Find user by ID
    # For security reasons the hashed password is omitted in the response
    # @param [String] user_name: ID of the user to retrieve
    # @return [Dry::Monads::Result<SftpgoClient::User>]
    def get_user(user_name:)
      validate_user_name(:user_name, user_name)

      wrap_response(@connection.get(user_path(user_name))).fmap { |r|
        SftpgoClient::User.new(r.body)
      }
    end

    # Adds a new user
    # @param [Hash] user
    # @return [Dry::Monads::Result<SftpgoClient::User>]
    def create_user(user)
      new_user = SftpgoClient::User.new(user)
      response = wrap_response(@connection.post(USERS_PATH, new_user))

      response.fmap { |r| SftpgoClient::User.new(r.body) }
    end

    # Update an existing user
    # @param [String] user_name: ID of the user to update
    # @param [Hash] user: a subset of user properties to update
    # @return [Dry::Monads::Result<SftpgoClient::ApiResponse>]
    def update_user(user_name:, user:)
      validate_user_name(:user_name, user_name)
      response = wrap_response(@connection.put(user_path(user_name), user))

      response.fmap { |r| SftpgoClient::ApiResponse.new(r.body) }
    end

    # Delete an existing user
    # @param user_name [String] ID of the user to delete
    # @return [Dry::Monads::Result<SftpgoClient::ApiResponse>]
    def delete_user(user_name:)
      validate_user_name(:user_name, user_name)

      wrap_response(@connection.delete(user_path(user_name))).fmap { |r| SftpgoClient::ApiResponse.new(r.body) }
    end

    private

    def user_path(user_name)
      "#{USERS_PATH}/#{user_name}"
    end

    def between_1_and_500(value)
      return Failure("#{value} was not a integer") unless value.is_a?(Integer)
      return Failure("#{value} was not between 1 and #{MAXIMUM_LIMIT}") unless (1..MAXIMUM_LIMIT).include?(value)

      Success(value)
    end

    def valid_order(value)
      return Success(value) if [SORT_ASCENDING, SORT_DESCENDING].include?(value)

      Failure("#{value} was not `ASC`/`DESC`")
    end
  end
end
