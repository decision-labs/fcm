# frozen_string_literal: true

module Fcm
  class Client
    # A Fcm Client class to handle notification setting methods
    module NotificationSetting
      GROUP_NOTIFICATION_BASE_URI = 'https://android.googleapis.com'
      END_POINT = '/gcm/notification'

      def create_notification_key(key_name, project_id, registration_ids = [])
        post_body = build_post_body(
          registration_ids,
          operation: 'create',
          notification_key_name: key_name
        )
        res = make_request(
          :post,
          GROUP_NOTIFICATION_BASE_URI,
          END_POINT,
          post_body,
          authorization_headers.merge('project_id' => project_id)
        )
        Fcm::Response.build_fcm_response(res)
      end

      def add_registration_ids(key_name, project_id, notification_key, register_ids)
        post_body = build_post_body(
          register_ids,
          operation: 'add',
          notification_key_name: key_name,
          notification_key: notification_key
        )
        res = make_request(
          :post,
          GROUP_NOTIFICATION_BASE_URI,
          END_POINT,
          post_body,
          authorization_headers.merge('project_id' => project_id)
        )
        Fcm::Response.build_fcm_response(res)
      end

      def remove_registration_ids(key_name, project_id, notif_key, register_ids)
        post_body = build_post_body(
          register_ids,
          operation: 'remove',
          notification_key_name: key_name,
          notification_key: notif_key
        )
        res = make_request(
          :post,
          GROUP_NOTIFICATION_BASE_URI,
          END_POINT,
          post_body,
          authorization_headers.merge('project_id' => project_id)
        )
        Fcm::Response.build_fcm_response(res)
      end

      def recover_notification_key(key_name, project_id)
        params = { notification_key_name: key_name }
        res = make_request(
          :get,
          GROUP_NOTIFICATION_BASE_URI,
          END_POINT,
          params,
          authorization_headers.merge('project_id' => project_id)
        )
        Fcm::Response.build_fcm_response(res)
      end

      private

      def build_post_body(registration_ids, options = {})
        ids = if registration_ids.is_a?(String)
                [registration_ids]
              else
                registration_ids
              end
        { registration_ids: ids }.merge(options)
      end
    end
  end
end
