require 'faraday'
require 'cgi'
require 'json'

class FCM
  BASE_URI = 'https://fcm.googleapis.com'
  DEFAULT_TIMEOUT = 30
  FORMAT = :json

  # constants
  INSTANCE_ID_API = 'https://iid.googleapis.com'
  TOPIC_REGEX = /[a-zA-Z0-9\-_.~%]+/

  attr_accessor :timeout, :api_key

  def initialize(api_key, client_options = {})
    @api_key = api_key
    @client_options = client_options
  end

  # See https://developers.google.com/cloud-messaging/http for more details.
  # { "notification": {
  #  "title": "Portugal vs. Denmark",
  #  "text": "5 to 1"
  # },
  # "to" : "bk3RNwTe3H0:CI2k_HHwgIpoDKCIZvvDMExUdFQ3P1..."
  # }
  # fcm = FCM.new("API_KEY")
  # fcm.send(
  #    ["4sdsx", "8sdsd"], # registration_ids
  #    { "notification": { "title": "Portugal vs. Denmark", "text": "5 to 1" }, "to" : "bk3RNwTe3HdFQ3P1..." }
  # )
  def send_notification(registration_ids, options = {})
    post_body = build_post_body(registration_ids, options)


    for_uri(BASE_URI) do |connection|
      response = connection.post('/fcm/send', post_body.to_json)
      build_response(response, registration_ids)
    end
  end
  alias send send_notification

  def create_notification_key(key_name, project_id, registration_ids = [])
    post_body = build_post_body(registration_ids, operation: 'create',
                                notification_key_name: key_name)

    update_group_messaging_setting(post_body, project_id)
  end
  alias create create_notification_key

  def add_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: 'add',
                                notification_key_name: key_name,
                                notification_key: notification_key)

    update_group_messaging_setting(post_body, project_id)
  end
  alias add add_registration_ids

  def remove_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: 'remove',
                                notification_key_name: key_name,
                                notification_key: notification_key)

    update_group_messaging_setting(post_body, project_id)
  end
  alias remove remove_registration_ids

  def recover_notification_key(key_name, project_id)
    params = {
      query: {
        notification_key_name: key_name
      }
    }

    extra_headers = {
      'project_id' => project_id
    }

    for_uri(BASE_URI, extra_headers) do |connection|
      response = connection.get('/fcm/notification', params)
      build_response(response)
    end
  end

  def send_with_notification_key(notification_key, options = {})
    body = { to: notification_key }.merge(options)
    execute_notification(body)
  end

  def topic_subscription(topic, registration_id)
    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.post("/iid/v1/#{registration_id}/rel/topics/#{topic}")
      build_response(response)
    end
  end

  def batch_topic_subscription(topic, registration_ids)
    manage_topics_relationship(topic, registration_ids, 'Add')
  end

  def batch_topic_unsubscription(topic, registration_ids)
    manage_topics_relationship(topic, registration_ids, 'Remove')
  end

  def manage_topics_relationship(topic, registration_ids, action)
    body = { to: "/topics/#{topic}", registration_tokens: registration_ids }

    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.post("/iid/v1:batch#{action}", body.to_json)
      build_response(response)
    end
  end

  def send_to_topic(topic, options = {})
    if topic.gsub(TOPIC_REGEX, "").length == 0
      send_with_notification_key('/topics/' + topic, options)
    end
  end

  def get_instance_id_info iid_token, options={}
    params = {
      query: options
    }

    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.get('/iid/info/'+iid_token, params)
      build_response(response)
    end
  end

  def subscribe_instance_id_to_topic iid_token, topic_name
    batch_subscribe_instance_ids_to_topic([iid_token], topic_name)
  end

  def unsubscribe_instance_id_from_topic iid_token, topic_name
    batch_unsubscribe_instance_ids_from_topic([iid_token], topic_name)
  end

  def batch_subscribe_instance_ids_to_topic instance_ids, topic_name
    manage_topics_relationship(topic_name, instance_ids, 'Add')
  end

  def batch_unsubscribe_instance_ids_from_topic instance_ids, topic_name
    manage_topics_relationship(topic_name, instance_ids, 'Remove')
  end

  def send_to_topic_condition(condition, options = {})
    if validate_condition?(condition)
      body = { condition: condition }.merge(options)
      execute_notification(body)
    end
  end

  private

  def for_uri(uri, extra_headers = {})
    retry_if_func = lambda do |env, exception|
      retryable_errors = [
        "Unavailable", "InternalServerError",
        "DeviceMessageRateExceeded", "TopicsMessageRateExceeded"]
      if defined?(exception.response) && defined?(exception.response.status) && exception.response.status == 200
        body = JSON.parse(exception.response.body)
        body["results"] != nil && body["results"].any? { |result| retryable_errors.include? result["error"]}
      else
        true
      end
    end
    retryable_exceptions = Faraday::Request::Retry::DEFAULT_EXCEPTIONS
    connection = ::Faraday.new(:url => uri) do |faraday|
      faraday.request :retry, max: 5, interval: 0.1, interval_randomness: 0.5, backoff_factor: 2,
                        exceptions: retryable_exceptions, retry_statuses: [200, *(500..599)], methods: [],
                        retry_if: retry_if_func
      faraday.adapter  Faraday.default_adapter
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["Authorization"] = "key=#{api_key}"
      extra_headers.each do |key, value|
        faraday.headers[key] = value
      end
    end
    yield connection
  end

  def build_post_body(registration_ids, options = {})
    ids = registration_ids.is_a?(String) ? [registration_ids] : registration_ids
    { registration_ids: ids }.merge(options)
  end

  def build_response(response, registration_ids = [])
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.status }
    case response.status
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

  def update_group_messaging_setting(body, project_id)
    extra_headers = {
      'project_id' => project_id
    }
    
    for_uri(BASE_URI, extra_headers) do |connection|
        response = connection.post('/fcm/notification', body.to_json)
        build_response(response)
    end
  end

  def execute_notification(body)
    for_uri(BASE_URI) do |connection|
      response = connection.post('/fcm/send', body.to_json)
      build_response(response)
    end
  end

  def has_canonical_id?(result)
    !result['registration_id'].nil?
  end

  def is_not_registered?(result)
    result['error'] == 'NotRegistered'
  end

  def validate_condition?(condition)
    validate_condition_format?(condition) && validate_condition_topics?(condition)
  end

  def validate_condition_format?(condition)
    bad_characters = condition.gsub(
      /(topics|in|\s|\(|\)|(&&)|[!]|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
      ""
    )
    bad_characters.length == 0
  end

  def validate_condition_topics?(condition)
    topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
    topics.all? { |topic| topic.gsub(TOPIC_REGEX, "").length == 0 }
  end
end
