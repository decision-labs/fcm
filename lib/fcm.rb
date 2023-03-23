# frozen_string_literal: true

require 'googleauth'
require 'fcm/client'
require 'fcm/client_v1'

class FCM
  BASE_URI = Fcm::Client::BASE_URI
  BASE_URI_V1 = Fcm::ClientV1::BASE_URI_V1
  DEFAULT_TIMEOUT = Fcm::Connection::DEFAULT_TIMEOUT

  GROUP_NOTIFICATION_BASE_URI = Fcm::Client::GROUP_NOTIFICATION_BASE_URI
  INSTANCE_ID_API = Fcm::Client::INSTANCE_ID_API

  def initialize(api_key, json_key_path = '', project_name = '')
    @api_key = api_key
    @json_key_path = json_key_path
    @project_name = project_name
  end

  # @param message [Hash] message hash
  # @see https://firebase.google.com/docs/cloud-messaging/send-message
  # @example
  #
  #   message = {
  #     "token": "4sdsx",
  #     "notification": {
  #       "title": "Breaking News",
  #       "body": "New news story available."
  #     },
  #     "data": {
  #       "story_id": "story_12345"
  #     },
  #     "android": {
  #       "notification": {
  #         "click_action": "TOP_STORY_ACTIVITY",
  #         "body": "Check out the Top Story"
  #       }
  #     },
  #     "apns": {
  #       "payload": {
  #         "aps": {
  #           "category" : "NEW_MESSAGE_CATEGORY"
  #         }
  #       }
  #     }
  #   }
  #
  #   fcm = FCM.new(api_key, json_key_path, project_name)
  #
  #   fcm.send_v1(message)
  #
  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::ClientV1#send_notification_v1} instead
  def send_notification_v1(message)
    warn '[DEPRECATION] `FCM#send_notification_v1` will be deprecated.'\
    'Use`Fcm::ClientV1.new(json_key_path).send_notification_v1` instead.'

    Fcm::ClientV1.new(@json_key_path).send_notification_v1(
      message, @project_name
    )
  end
  alias send_v1 send_notification_v1

  # @see https://developers.google.com/cloud-messaging/http
  # @example
  #   message = { "notification": {
  #    "title": "Portugal vs. Denmark",
  #    "text": "5 to 1"
  #   },
  #   "to" : "bk3RNwTe3H0:CI2k_HHwgIpoDKCIZvvDMExUdFQ3P1..."
  #   }
  #   fcm = FCM.new("API_KEY")
  #   fcm.send(
  #      ["4sdsx", "8sdsd"], # registration_ids
  #      message
  #   )
  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#send_notification_v1} instead
  def send_notification(registration_ids, options = {})
    deprecate_warning(:send_notification)
    Fcm::Client.new(@api_key).send_notification(registration_ids, options)
  end

  alias send send_notification

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#create_notification_key} instead
  def create_notification_key(key_name, project_id, registration_ids = [])
    deprecate_warning(:create_notification_key)
    Fcm::Client.new(@api_key).create_notification_key(
      key_name, project_id, registration_ids
    )
  end

  alias create create_notification_key

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#add_registration_ids} instead
  def add_registration_ids(key_name, project_id, notification_key, registration_ids)
    deprecate_warning(:add_registration_ids)
    Fcm::Client.new(@api_key).add_registration_ids(
      key_name, project_id, notification_key, registration_ids
    )
  end

  alias add add_registration_ids

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#remove_registration_ids} instead
  def remove_registration_ids(key_name, project_id, notification_key, registration_ids)
    deprecate_warning(:remove_registration_ids)
    Fcm::Client.new(@api_key).remove_registration_ids(
      key_name, project_id, notification_key, registration_ids
    )
  end

  alias remove remove_registration_ids

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#recover_notification_key} instead
  def recover_notification_key(key_name, project_id)
    deprecate_warning(:recover_notification_key)
    Fcm::Client.new(@api_key).recover_notification_key(key_name, project_id)
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#send_with_notification_key} instead
  def send_with_notification_key(notification_key, options = {})
    deprecate_warning(:send_with_notification_key)
    Fcm::Client.new(@api_key).send_with_notification_key(
      notification_key, options
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#topic_subscription} instead
  def topic_subscription(topic, registration_id)
    deprecate_warning(:topic_subscription)
    Fcm::Client.new(@api_key).topic_subscription(topic, registration_id)
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#batch_topic_subscription} instead
  def batch_topic_subscription(topic, registration_ids)
    deprecate_warning(:batch_topic_subscription)
    Fcm::Client.new(@api_key).batch_topic_subscription(
      topic, registration_ids
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#batch_topic_unsubscription} instead
  def batch_topic_unsubscription(topic, registration_ids)
    deprecate_warning(:batch_topic_unsubscription)
    Fcm::Client.new(@api_key).batch_topic_unsubscription(
      topic, registration_ids
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#send_to_topic} instead
  def send_to_topic(topic, options = {})
    deprecate_warning(:send_to_topic)
    Fcm::Client.new(@api_key).send_to_topic(topic, options)
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#get_instance_id_info} instead
  def get_instance_id_info(iid_token, options = {})
    deprecate_warning(:get_instance_id_info)
    Fcm::Client.new(@api_key).get_instance_id_info(iid_token, options)
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#subscribe_instance_id_to_topic} instead
  def subscribe_instance_id_to_topic(iid_token, topic_name)
    deprecate_warning(:subscribe_instance_id_to_topic)
    Fcm::Client.new(@api_key).subscribe_instance_id_to_topic(
      iid_token, topic_name
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#unsubscribe_instance_id_from_topic} instead
  def unsubscribe_instance_id_from_topic(iid_token, topic_name)
    deprecate_warning(:unsubscribe_instance_id_from_topic)
    Fcm::Client.new(@api_key).unsubscribe_instance_id_from_topic(
      iid_token, topic_name
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#batch_subscribe_instance_ids_to_topic} instead
  def batch_subscribe_instance_ids_to_topic(instance_ids, topic_name)
    deprecate_warning(:batch_subscribe_instance_ids_to_topic)
    Fcm::Client.new(@api_key).batch_subscribe_instance_ids_to_topic(
      instance_ids, topic_name
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#batch_unsubscribe_instance_ids_from_topic} instead
  def batch_unsubscribe_instance_ids_from_topic(instance_ids, topic_name)
    deprecate_warning(:batch_unsubscribe_instance_ids_from_topic)
    Fcm::Client.new(@api_key).batch_unsubscribe_instance_ids_from_topic(
      instance_ids, topic_name
    )
  end

  # @return [Fcm::Response] a custom fcm response hash
  # @deprecated Use {Fcm::Client#send_to_topic_condition} instead
  def send_to_topic_condition(condition, options = {})
    deprecate_warning(:send_to_topic_condition)
    Fcm::Client.new(@api_key).send_to_topic_condition(condition, options)
  end

  private

  def deprecate_warning(method)
    warn "[DEPRECATION] `FCM##{method} will be deprecated." \
    "Please use `Fcm::Client.new(api_key).#{method}` instead."
  end

  def json_key
    @json_key ||= if @json_key_path.respond_to?(:read)
                    @json_key_path
                  else
                    File.open(@json_key_path)
                  end
  end
end
