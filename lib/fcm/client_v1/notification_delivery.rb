# frozen_string_literal: true

module Fcm
  class ClientV1
    # Handle notification delivery methods
    module NotificationDilivery
      BASE_URI_V1 = 'https://fcm.googleapis.com/v1/projects/'
      TOKEN_URI = 'https://www.googleapis.com/auth/firebase.messaging'

      def send_notification_v1(message, project_name)
        return if project_name.empty?

        post_body = { 'message': message }
        end_point = "#{project_name}/messages:send"

        res = make_request(
          :post, BASE_URI_V1, end_point, post_body, authorization_headers
        )
        Fcm::Response.build_fcm_response(res)
      end
    end
  end
end
