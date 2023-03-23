# frozen_string_literal: true

module Fcm
  class Client
    # Handle notification delivery methods
    module NotificationDilivery
      BASE_URI = 'https://fcm.googleapis.com'
      END_POINT = '/fcm/send'

      def send_notification(registration_ids, options = {})
        post_body = build_post_body(registration_ids, options)
        res = make_request(
          :post, BASE_URI, END_POINT, post_body, authorization_headers
        )
        Fcm::Response.build_fcm_response(res, registration_ids)
      end

      def send_with_notification_key(notification_key, options = {})
        body = { to: notification_key }.merge(options)
        res = make_request(
          :post, BASE_URI, END_POINT, body, authorization_headers
        )
        Fcm::Response.build_fcm_response(res)
      end

      def send_to_topic_condition(condition, options = {})
        return unless validate_condition?(condition)

        body = { condition: condition }.merge(options)

        res = make_request(
          :post, BASE_URI, END_POINT, body, authorization_headers
        )
        Fcm::Response.build_fcm_response(res)
      end

      def send_to_topic(topic, options = {})
        return unless topic.gsub(/[a-zA-Z0-9\-_.~%]+/, '').length.zero?

        send_with_notification_key("/topics/#{topic}", options)
      end

      private

      def validate_condition?(condition)
        validate_condition_format?(
          condition
        ) && validate_condition_topics?(
          condition
        )
      end

      def validate_condition_format?(condition)
        bad_characters = condition.gsub(
          /(topics|in|\s|\(|\)|(&&)|!|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
          ''
        )
        bad_characters.length.zero?
      end

      def validate_condition_topics?(condition)
        topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
        topics.all? { |topic| topic.gsub(/[a-zA-Z0-9\-_.~%]+/, '').length.zero? }
      end
    end
  end
end
