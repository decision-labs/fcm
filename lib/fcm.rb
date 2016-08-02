require 'httparty'
require 'cgi'
require 'json'

class FCM
  include HTTParty
  base_uri 'https://fcm.googleapis.com/fcm'
  default_timeout 30
  format :json

  # constants
  GROUP_NOTIFICATION_BASE_URI = 'https://android.googleapis.com/gcm'

  attr_accessor :timeout, :api_key

  def initialize(api_key, client_options = {})
    @api_key = api_key
    @client_options = client_options
  end

  # {
  #   "collapse_key": "score_update",
  #   "time_to_live": 108,
  #   "delay_while_idle": true,
  #   "registration_ids": ["4", "8", "15", "16", "23", "42"],
  #   "data" : {
  #     "score": "5x1",
  #     "time": "15:10"
  #   }
  # }
  # fcm = FCM.new("API_KEY")
  # fcm.send(registration_ids: ["4sdsx", "8sdsd"], {data: {score: "5x1"}})
  def send_notification(registration_ids, options = {})
    post_body = build_post_body(registration_ids, options)

    params = {
      body: post_body.to_json,
      headers: {
        'Authorization' => "key=#{@api_key}",
        'Content-Type' => 'application/json'
      }
    }
    response = self.class.post('/send', params.merge(@client_options))
    build_response(response, registration_ids)
  end
  alias send send_notification

  def create_notification_key(key_name, project_id, registration_ids = [])
    post_body = build_post_body(registration_ids, operation: 'create',
                                notification_key_name: key_name)

    params = {
      body: post_body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'project_id' => project_id,
        'Authorization' => "key=#{@api_key}"
      }
    }

    response = nil

    for_uri(GROUP_NOTIFICATION_BASE_URI) do
      response = self.class.post('/notification', params.merge(@client_options))
    end

    build_response(response)
  end
  alias create create_notification_key

  def add_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: 'add',
                                notification_key_name: key_name,
                                notification_key: notification_key)

    params = {
      body: post_body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'project_id' => project_id,
        'Authorization' => "key=#{@api_key}"
      }
    }

    response = nil

    for_uri(GROUP_NOTIFICATION_BASE_URI) do
      response = self.class.post('/notification', params.merge(@client_options))
    end
    build_response(response)
  end
  alias add add_registration_ids

  def remove_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: 'remove',
                                notification_key_name: key_name,
                                notification_key: notification_key)

    params = {
      body: post_body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'project_id' => project_id,
        'Authorization' => "key=#{@api_key}"
      }
    }

    response = nil

    for_uri(GROUP_NOTIFICATION_BASE_URI) do
      response = self.class.post('/notification', params.merge(@client_options))
    end
    build_response(response)
  end
  alias remove remove_registration_ids

  def recover_notification_key(key_name, project_id)
    params = {
      query: {
        notification_key_name: key_name
      },
      headers: {
        'Content-Type' => 'application/json',
        'project_id' => project_id,
        'Authorization' => "key=#{@api_key}"
      }
    }

    response = nil

    for_uri(GROUP_NOTIFICATION_BASE_URI) do
      response = self.class.post('/notification', params.merge(@client_options))
    end
    build_response(response)
  end

  def send_with_notification_key(notification_key, options = {})
    body = { to: notification_key }.merge(options)

    params = {
      body: body.to_json,
      headers: {
        'Authorization' => "key=#{@api_key}",
        'Content-Type' => 'application/json'
      }
    }

    response = self.class.post('/send', params.merge(@client_options))
    build_response(response)
  end

  def send_to_topic(topic, options = {})
    if topic =~ /[a-zA-Z0-9\-_.~%]+/
      send_with_notification_key('/topics/' + topic, options)
    end
  end

  private

  def for_uri(uri)
    current_uri = self.class.base_uri
    self.class.base_uri uri
    yield
    self.class.base_uri current_uri
  end

  def build_post_body(registration_ids, options = {})
    { registration_ids: registration_ids }.merge(options)
  end

  def build_response(response, registration_ids = [])
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.code }
    case response.code
    when 200
      response_hash[:response] = 'success'
      body = JSON.parse(body) unless body.empty?
      response_hash[:canonical_ids] = build_canonical_ids(body, registration_ids) unless registration_ids.empty?
      response_hash[:not_registered_ids] = build_not_registered_ids(body, registration_ids) unless registration_ids.empty?
    when 400
      response_hash[:response] = 'Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields.'
    when 401
      response_hash[:response] = 'There was an error authenticating the sender account.'
    when 503
      response_hash[:response] = 'Server is temporarily unavailable.'
    when 500..599
      response_hash[:response] = 'There was an internal error in the FCM server while trying to process the request.'
    end
    response_hash
  end

  def build_canonical_ids(body, registration_ids)
    canonical_ids = []
    unless body.empty?
      if body['canonical_ids'] > 0
        body['results'].each_with_index do |result, index|
          canonical_ids << { old: registration_ids[index], new: result['registration_id'] } if has_canonical_id?(result)
        end
      end
    end
    canonical_ids
  end

  def build_not_registered_ids(body, registration_id)
    not_registered_ids = []
    unless body.empty?
      if body['failure'] > 0
        body['results'].each_with_index do |result, index|
          not_registered_ids << registration_id[index] if is_not_registered?(result)
        end
      end
    end
    not_registered_ids
  end

  def has_canonical_id?(result)
    !result['registration_id'].nil?
  end

  def is_not_registered?(result)
    result['error'] == 'NotRegistered'
  end
end
