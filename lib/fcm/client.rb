# frozen_string_literal: true

require 'fcm/connection'
require 'fcm/response'
require 'fcm/client/notification_delivery'
require 'fcm/client/notification_setting'
require 'fcm/client/instance_topic_management'

module Fcm
  # Fcm Client class for legacy http protocol API connections
  #
  # @see https://firebase.google.com/docs/cloud-messaging/http-server-ref
  class Client
    include Fcm::Connection
    include Fcm::Response
    include Fcm::Client::NotificationDilivery
    include Fcm::Client::NotificationSetting
    include Fcm::Client::InstanceTopicManagement

    # @see https://firebase.google.com/docs/projects/api-keys
    # @param api_key [String] Firebase API key
    # @return [Client] client instance
    def initialize(api_key)
      @api_key = api_key
    end

    private

    def authorization_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "key=#{@api_key}"
      }
    end
  end
end
