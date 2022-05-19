# frozen_string_literal: true

require 'fcm/error'

module Fcm
  # Custome Fcm response
  module Response
    class << self
      # Converts the faraday response into a custom fcm response
      #
      # @param response [Faraday::Response] a faraday response object
      # @return [Hash] a custom fcm response hash
      def build_fcm_response(response, registration_ids = [])
        return success_response(response, registration_ids) if response.success?

        failure_response(response)
      end

      private

      def success_response(response, registration_ids)
        body = response.body || {}
        response_hash = {
          body: body,
          headers: response.headers,
          status_code: response.status,
          response: 'success'
        }
        return response_hash if registration_ids.empty?

        body = JSON.parse(body) unless body.empty?
        response_hash[:canonical_ids] = build_canonical_ids(
          body, registration_ids
        )
        response_hash[:not_registered_ids] = build_not_registered_ids(
          body, registration_ids
        )
        response_hash
      end

      def failure_response(response)
        body = response.body || {}
        response_hash = {
          body: body,
          headers: response.headers,
          status_code: response.status
        }

        response_hash[:response] = case response.status.to_i
                                   when 400
                                     Fcm::Error::ERROR_RESPONSE_400
                                   when 401
                                     Fcm::Error::ERROR_RESPONSE_401
                                   when 503
                                     Fcm::Error::ERROR_RESPONSE_503
                                   when 500..599
                                     Fcm::Error::ERROR_RESPONSE_50X
                                   end
        response_hash
      end

      def build_canonical_ids(body, registration_ids)
        canonical_ids = []
        return canonical_ids if body.empty? || body['canonical_ids'] <= 0

        body['results'].each_with_index do |result, index|
          return canonical_ids unless canonical_id?(result)

          canonical_ids << {
            old: registration_ids[index], new: result['registration_id']
          }
        end
        canonical_ids
      end

      def build_not_registered_ids(body, registration_id)
        not_registered_ids = []
        return not_registered_ids if body.empty?

        if body['failure'].positive?
          body['results'].each_with_index do |result, index|
            not_registered_ids << registration_id[index] if not_registered?(result)
          end
        end
        not_registered_ids
      end

      def canonical_id?(result)
        !result['registration_id'].nil?
      end

      def not_registered?(result)
        result['error'] == 'NotRegistered'
      end
    end
  end
end
