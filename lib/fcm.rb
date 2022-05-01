require "faraday"
require "cgi"
require "json"
require "googleauth"

class FCM
  BASE_URI = "https://fcm.googleapis.com"
  BASE_URI_V1 = "https://fcm.googleapis.com/v1/projects/"
  DEFAULT_TIMEOUT = 30

  GROUP_NOTIFICATION_BASE_URI = "https://android.googleapis.com"
  INSTANCE_ID_API = "https://iid.googleapis.com"
  TOPIC_REGEX = /[a-zA-Z0-9\-_.~%]+/

  def initialize(api_key, json_key_path = "", project_name = "", client_options = {})
    @api_key = api_key
    @client_options = client_options
    @json_key_path = json_key_path
    @project_name = project_name
  end

  # See https://firebase.google.com/docs/cloud-messaging/send-message
  # {
  #   "token": "4sdsx",
  #   "notification": {
  #     "title": "Breaking News",
  #     "body": "New news story available."
  #   },
  #   "data": {
  #     "story_id": "story_12345"
  #   },
  #   "android": {
  #     "notification": {
  #       "click_action": "TOP_STORY_ACTIVITY",
  #       "body": "Check out the Top Story"
  #     }
  #   },
  #   "apns": {
  #     "payload": {
  #       "aps": {
  #         "category" : "NEW_MESSAGE_CATEGORY"
  #       }
  #     }
  #   }
  # }
  # fcm = FCM.new(api_key, json_key_path, project_name)
  # fcm.send_v1(
  #    { "token": "4sdsx",, "to" : "notification": {}.. }
  # )
  def send_notification_v1(message)
    return if @project_name.empty?

    post_body = { 'message': message }.to_json
    end_point = "#{@project_name}/messages:send"
    extra_headers = { 'Authorization' => "Bearer #{jwt_token}" }

    res = perform_request(:post, BASE_URI_V1, end_point, post_body, **extra_headers)
    build_response(res)
  end

  alias send_v1 send_notification_v1

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
    end_point = '/fcm/send'

    res = perform_request(:post, BASE_URI, end_point, post_body)
    build_response(res, registration_ids)
  end

  alias send send_notification

  def create_notification_key(key_name, project_id, registration_ids = [])
    post_body = build_post_body(registration_ids, operation: "create",
                                                  notification_key_name: key_name)

    extra_headers = {
      "project_id" => project_id,
    }

    end_point = 'gcm/notification'

    res = perform_request(:post, GROUP_NOTIFICATION_BASE_URI, end_point, post_body, **extra_headers)
    build_response(res)
  end

  alias create create_notification_key

  def add_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: "add",
                                                  notification_key_name: key_name,
                                                  notification_key: notification_key)

    end_point = '/gcm/notification'
    extra_headers = {
      "project_id" => project_id,
    }

    res = perform_request(:post, GROUP_NOTIFICATION_BASE_URI, end_point, post_body, **extra_headers)
    build_response(res)
  end

  alias add add_registration_ids

  def remove_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: "remove",
                                                  notification_key_name: key_name,
                                                  notification_key: notification_key)

    end_point = 'gcm/notification'
    extra_headers = {
      "project_id" => project_id,
    }

    res = perform_request(:post, GROUP_NOTIFICATION_BASE_URI, end_point, post_body, **extra_headers)
    build_response(res)
  end

  alias remove remove_registration_ids

  def recover_notification_key(key_name, project_id)
    params = { notification_key_name: key_name }

    end_point = 'gcm/notification'
    extra_headers = {
      "project_id" => project_id,
    }

    res = perform_request(:get, GROUP_NOTIFICATION_BASE_URI, end_point, params, **extra_headers)
    build_response(res)
  end

  def send_with_notification_key(notification_key, options = {})
    body = { to: notification_key }.merge(options)
    execute_notification(body)
  end

  def topic_subscription(topic, registration_id)
    end_point = "/iid/v1/#{registration_id}/rel/topics/#{topic}"
    res = perform_request(:post, INSTANCE_ID_API, end_point)
    build_response(res)
  end

  def batch_topic_subscription(topic, registration_ids)
    manage_topics_relationship(topic, registration_ids, "Add")
  end

  def batch_topic_unsubscription(topic, registration_ids)
    manage_topics_relationship(topic, registration_ids, "Remove")
  end

  def manage_topics_relationship(topic, registration_ids, action)
    post_body = { to: "/topics/#{topic}", registration_tokens: registration_ids }.to_json
    end_point = "/iid/v1:batch#{action}"

    res = perform_request(:post, INSTANCE_ID_API, end_point, post_body)
    build_response(res)
  end

  def send_to_topic(topic, options = {})
    if topic.gsub(TOPIC_REGEX, "").length == 0
      send_with_notification_key("/topics/" + topic, options)
    end
  end

  def get_instance_id_info(iid_token, options = {})
    params = options

    end_point = "/iid/info/" + iid_token
    res = perform_request(:get, INSTANCE_ID_API, end_point, params)
    build_response(res)
  end

  def subscribe_instance_id_to_topic(iid_token, topic_name)
    batch_subscribe_instance_ids_to_topic([iid_token], topic_name)
  end

  def unsubscribe_instance_id_from_topic(iid_token, topic_name)
    batch_unsubscribe_instance_ids_from_topic([iid_token], topic_name)
  end

  def batch_subscribe_instance_ids_to_topic(instance_ids, topic_name)
    manage_topics_relationship(topic_name, instance_ids, "Add")
  end

  def batch_unsubscribe_instance_ids_from_topic(instance_ids, topic_name)
    manage_topics_relationship(topic_name, instance_ids, "Remove")
  end

  def send_to_topic_condition(condition, options = {})
    if validate_condition?(condition)
      body = { condition: condition }.merge(options)
      execute_notification(body)
    end
  end

  private


  def perform_request(method, base_uri, end_point, body, **extra_headers)
    conn_settings(method, base_uri) do |conn|

      conn.headers["Content-Type"] = "application/json"
      conn.headers['Authorization'] = "key=#{@api_key}"

      extra_headers.each do |key, value|
        conn.headers[key] = value
      end
      conn.send(method, end_point, body)
    end
  end

  def conn_settings(method, base_uri)
    conn = ::Faraday.new(
      url: base_uri,
      request: { timeout: DEFAULT_TIMEOUT }
    )
    yield conn
  end

  def build_post_body(registration_ids, options = {})
    ids = registration_ids.is_a?(String) ? [registration_ids] : registration_ids
    { registration_ids: ids }.merge(options).to_json
  end

  def build_response(response, registration_ids = [])
    body = response.body || {}
    response_hash = { body: body, headers: response.headers, status_code: response.status }
    case response.status
    when 200
      response_hash[:response] = "success"
      body = JSON.parse(body) unless body.empty?
      response_hash[:canonical_ids] = build_canonical_ids(body, registration_ids) unless registration_ids.empty?
      response_hash[:not_registered_ids] = build_not_registered_ids(body, registration_ids) unless registration_ids.empty?
    when 400
      response_hash[:response] = "Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields."
    when 401
      response_hash[:response] = "There was an error authenticating the sender account."
    when 503
      response_hash[:response] = "Server is temporarily unavailable."
    when 500..599
      response_hash[:response] = "There was an internal error in the FCM server while trying to process the request."
    end
    response_hash
  end

  def build_canonical_ids(body, registration_ids)
    canonical_ids = []
    unless body.empty?
      if body["canonical_ids"] > 0
        body["results"].each_with_index do |result, index|
          canonical_ids << { old: registration_ids[index], new: result["registration_id"] } if has_canonical_id?(result)
        end
      end
    end
    canonical_ids
  end

  def build_not_registered_ids(body, registration_id)
    not_registered_ids = []
    unless body.empty?
      if body["failure"] > 0
        body["results"].each_with_index do |result, index|
          not_registered_ids << registration_id[index] if is_not_registered?(result)
        end
      end
    end
    not_registered_ids
  end

  def execute_notification(body)
    end_point = '/fcm/send'
    res = perform_request(:post, BASE_URI, end_point, body.to_json)
    build_response(res)
  end

  def has_canonical_id?(result)
    !result["registration_id"].nil?
  end

  def is_not_registered?(result)
    result["error"] == "NotRegistered"
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

  def jwt_token
    scope = "https://www.googleapis.com/auth/firebase.messaging"
    @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: json_key,
      scope: scope,
    )
    token = @authorizer.fetch_access_token!
    token["access_token"]
  end

  def json_key
    @json_key ||= if @json_key_path.respond_to?(:read)
                    @json_key_path
                  else
                    File.open(@json_key_path)
                  end
  end
end
