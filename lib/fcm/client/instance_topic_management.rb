# frozen_string_literal: true

module Fcm
  class Client
    # A Fcm Client class to handle notification setting methods
    module InstanceTopicManagement
      INSTANCE_ID_API = 'https://iid.googleapis.com'

      def manage_topics_relationship(topic, registration_ids, action)
        body = { to: "/topics/#{topic}", registration_tokens: registration_ids }
        end_point = "/iid/v1:batch#{action}"
        res = make_request(
          :post, INSTANCE_ID_API, end_point, body, authorization_headers
        )
        Fcm::Response.build_fcm_response(res, registration_ids)
      end

      def topic_subscription(topic, registration_id)
        end_point = "/iid/v1/#{registration_id}/rel/topics/#{topic}"
        res = make_request(
          :post, INSTANCE_ID_API, end_point, nil, authorization_headers
        )
        Fcm::Response.build_fcm_response(res)
      end

      def get_instance_id_info(iid_token, options = {})
        params = options
        end_point = "/iid/info/#{iid_token}"
        res = make_request(
          :get, INSTANCE_ID_API, end_point, params, authorization_headers
        )
        Fcm::Response.build_fcm_response(res)
      end

      def batch_topic_subscription(topic, registration_ids)
        manage_topics_relationship(topic, registration_ids, 'Add')
      end

      def batch_topic_unsubscription(topic, registration_ids)
        manage_topics_relationship(topic, registration_ids, 'Remove')
      end

      def batch_subscribe_instance_ids_to_topic(instance_ids, topic_name)
        manage_topics_relationship(topic_name, instance_ids, 'Add')
      end

      def batch_unsubscribe_instance_ids_from_topic(instance_ids, topic_name)
        manage_topics_relationship(topic_name, instance_ids, 'Remove')
      end

      def subscribe_instance_id_to_topic(iid_token, topic_name)
        batch_subscribe_instance_ids_to_topic([iid_token], topic_name)
      end

      def unsubscribe_instance_id_from_topic(iid_token, topic_name)
        batch_unsubscribe_instance_ids_from_topic([iid_token], topic_name)
      end
    end
  end
end
