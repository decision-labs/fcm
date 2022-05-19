# frozen_string_literal: true

module Fcm
  # Custom Fcm errors
  class Error < StandardError
    ERROR_RESPONSE_400 = 'Only applies for JSON requests.'\
    ' Indicates that the request could not be parsed as JSON,'\
    ' or it contained invalid fields.'

    ERROR_RESPONSE_401 = 'There was an error authenticating'\
    ' the sender account.'

    ERROR_RESPONSE_503 = 'Server is temporarily unavailable.'

    ERROR_RESPONSE_50X = 'There was an internal error in the'\
        ' FCM server while trying to process the request.'
  end

  # Raised on errors in the 400-499 range
  class ClientError < Error; end

  # Raised when Faraday returns a 400 HTTP status code
  class BadRequest < ClientError; end

  # Raised when Faraday returns a 401 HTTP status code
  class Unauthorized < ClientError; end

  # Raised on errors in the 500-599 range
  class ServerError < Error; end

  # Raised when Faraday returns a 503 HTTP status code
  class ServiceUnavailable < ServerError; end
end
