# frozen_string_literal: true

require 'fcm/connection'
require 'fcm/response'
require 'fcm/client_v1/notification_delivery'

module Fcm
  # Fcm Client class for http v1 protocol API connections
  #
  # @see https://firebase.google.com/docs/cloud-messaging/migrate-v1
  class ClientV1
    include Fcm::Connection
    include Fcm::Response
    include Fcm::ClientV1::NotificationDilivery

    TOKEN_URI = 'https://www.googleapis.com/auth/firebase.messaging'

    # @see https://firebase.google.com/docs/projects/provisioning/configure-oauth#auth
    # @param json_key_path [String] file path to service_account_key.json
    # @return [ClientV1] client_v1 instance
    def initialize(json_key_path)
      @json_key_path = json_key_path
    end

    private

    def authorization_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{jwt_token}"
      }
    end

    def jwt_token
      @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: json_key,
        scope: TOKEN_URI
      )
      token = @authorizer.fetch_access_token!
      token['access_token']
    end

    def json_key
      @json_key ||= if @json_key_path.respond_to?(:read)
                      @json_key_path
                    else
                      File.open(@json_key_path)
                    end
    end
  end
end
