# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday/typhoeus'

module Fcm
  # underhood http client using faraday with typhoeus adapter
  module Connection
    DEFAULT_TIMEOUT = 30

    def make_request(method, base_uri, end_point, body, headers)
      url = "#{base_uri}#{end_point}"
      agent.send(method, url, body, headers)
    end

    private

    def agent
      @agent ||= Faraday.new(
        request: { timeout: DEFAULT_TIMEOUT }
      ) do |builder|
        builder.request :retry, exceptions: [
          Faraday::TimeoutError, Faraday::ConnectionFailed
        ]
        builder.request :json
        builder.response :json
        builder.adapter :typhoeus
      end
    end
  end
end
