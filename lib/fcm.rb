# frozen_string_literal: true

require "faraday"
require "json"
require "googleauth"

class FCM
  class InvalidCredentialError < StandardError; end

  BASE_URI = "https://fcm.googleapis.com"
  BASE_URI_V1 = "https://fcm.googleapis.com/v1/projects/"
  DEFAULT_TIMEOUT = 30
  DEFAULT_KEEP_ALIVE_IDLE_TIMEOUT_SECONDS = 30
  DEFAULT_KEEP_ALIVE_POOL_SIZE = 1

  GROUP_NOTIFICATION_BASE_URI = "https://android.googleapis.com"
  INSTANCE_ID_API = "https://iid.googleapis.com"
  TOPIC_REGEX = /[a-zA-Z0-9\-_.~%]+/.freeze

  def initialize(json_key_path = "", project_name = "", http_options = {}, faraday_configurer = nil)
    @json_key_path = json_key_path
    @project_name = project_name
    @http_options = http_options
    @faraday_configurer = faraday_configurer
    @keep_alive_connections = http_options.fetch(:keep_alive_connections, false)
    @keep_alive_idle_timeout_seconds =
      http_options.fetch(:keep_alive_idle_timeout_seconds, DEFAULT_KEEP_ALIVE_IDLE_TIMEOUT_SECONDS)
    @keep_alive_pool_size = http_options.fetch(:keep_alive_pool_size, DEFAULT_KEEP_ALIVE_POOL_SIZE)

    # Per-instance key for the thread-local connection cache so multiple FCM
    # clients in the same process do not share sockets.
    @thread_connections_key = :"_fcm_connections_#{object_id}"

    require "faraday/net_http_persistent" if @keep_alive_connections
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
  # fcm = FCM.new(json_key_path, project_name)
  # fcm.send_v1(
  #    { "token": "4sdsx",, "to" : "notification": {}.. }
  # )
  def send_notification_v1(message)
    return if @project_name.empty?

    post_body = { message: message }
    for_uri(BASE_URI_V1) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", post_body.to_json
      )
      build_response(response)
    end
  end

  alias send_v1 send_notification_v1

  def create_notification_key(key_name, project_id, registration_ids = [])
    post_body = build_post_body(registration_ids, operation: "create",
                                                  notification_key_name: key_name)

    extra_headers = {
      "project_id" => project_id
    }

    for_uri(GROUP_NOTIFICATION_BASE_URI, extra_headers) do |connection|
      response = connection.post("/gcm/notification", post_body.to_json)
      build_response(response)
    end
  end

  alias create create_notification_key

  def add_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: "add",
                                                  notification_key_name: key_name,
                                                  notification_key: notification_key)

    extra_headers = {
      "project_id" => project_id
    }

    for_uri(GROUP_NOTIFICATION_BASE_URI, extra_headers) do |connection|
      response = connection.post("/gcm/notification", post_body.to_json)
      build_response(response)
    end
  end

  alias add add_registration_ids

  def remove_registration_ids(key_name, project_id, notification_key, registration_ids)
    post_body = build_post_body(registration_ids, operation: "remove",
                                                  notification_key_name: key_name,
                                                  notification_key: notification_key)

    extra_headers = {
      "project_id" => project_id
    }

    for_uri(GROUP_NOTIFICATION_BASE_URI, extra_headers) do |connection|
      response = connection.post("/gcm/notification", post_body.to_json)
      build_response(response)
    end
  end

  alias remove remove_registration_ids

  def recover_notification_key(key_name, project_id)
    params = { notification_key_name: key_name }

    extra_headers = {
      "project_id" => project_id
    }

    for_uri(GROUP_NOTIFICATION_BASE_URI, extra_headers) do |connection|
      response = connection.get("/gcm/notification", params)
      build_response(response)
    end
  end

  def topic_subscription(topic, registration_token)
    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.post(
        "/iid/v1/#{registration_token}/rel/topics/#{topic}"
      )
      build_response(response)
    end
  end

  def topic_unsubscription(topic, registration_token)
    batch_topic_unsubscription(topic, [registration_token])
  end

  def batch_topic_subscription(topic, registration_tokens)
    manage_topics_relationship(topic, registration_tokens, "Add")
  end

  def batch_topic_unsubscription(topic, registration_tokens)
    manage_topics_relationship(topic, registration_tokens, "Remove")
  end

  def manage_topics_relationship(topic, registration_tokens, action)
    body = { to: "/topics/#{topic}", registration_tokens: registration_tokens }

    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.post("/iid/v1:batch#{action}", body.to_json)
      build_response(response)
    end
  end

  def get_instance_id_info(iid_token, options = {})
    params = options

    for_uri(INSTANCE_ID_API) do |connection|
      response = connection.get("/iid/info/#{iid_token}", params)
      build_response(response)
    end
  end

  def send_to_topic(topic, options = {})
    return unless topic.gsub(TOPIC_REGEX, "").empty?

    body = { message: { topic: topic }.merge(options) }

    for_uri(BASE_URI_V1) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", body.to_json
      )
      build_response(response)
    end
  end

  def send_to_topic_condition(condition, options = {})
    return unless validate_condition?(condition)

    body = { message: { condition: condition }.merge(options) }

    for_uri(BASE_URI_V1) do |connection|
      response = connection.post(
        "#{@project_name}/messages:send", body.to_json
      )
      build_response(response)
    end
  end

  private

  def for_uri(uri, extra_headers = {}, &block)
    if @keep_alive_connections
      with_persistent_connection(uri, extra_headers, &block)
    else
      yield build_one_shot_connection(uri, extra_headers)
    end
  end

  def build_one_shot_connection(uri, extra_headers)
    ::Faraday.new(url: uri, request: request_options) do |faraday|
      faraday.adapter Faraday.default_adapter
      apply_default_headers(faraday, extra_headers)
      @faraday_configurer.call(faraday) if @faraday_configurer
    end
  end

  # Reuses a thread-local Faraday connection (one per uri) backed by
  # net-http-persistent so the TCP/TLS handshake and HTTP/2 stream are
  # amortised across requests. Bearer tokens and per-call headers are
  # re-applied each yield because JWTs expire and extra_headers vary.
  # On error, the cached connection is dropped: the underlying socket may
  # be half-closed and reusing it would just fail again.
  def with_persistent_connection(uri, extra_headers)
    connection = persistent_connection_for(uri)
    apply_default_headers(connection, extra_headers)
    yield connection
  rescue StandardError
    discard_persistent_connection(uri)
    raise
  end

  def apply_default_headers(connection, extra_headers)
    connection.headers["Content-Type"] = "application/json"
    connection.headers["Authorization"] = "Bearer #{jwt_token}"
    connection.headers["access_token_auth"] = "true"
    extra_headers.each { |key, value| connection.headers[key] = value }
  end

  # Net::HTTP is not thread-safe, so connections are cached per (thread, uri)
  # rather than shared across threads.
  def persistent_connection_for(uri)
    thread_connections[uri] ||= build_persistent_connection(uri)
  end

  def discard_persistent_connection(uri)
    connection = thread_connections.delete(uri)
    connection.close if connection.respond_to?(:close)
  end

  def thread_connections
    Thread.current[@thread_connections_key] ||= {}
  end

  def request_options
    {
      timeout: @http_options.fetch(:timeout, DEFAULT_TIMEOUT),
      open_timeout: @http_options.fetch(:open_timeout, DEFAULT_TIMEOUT)
    }
  end

  def build_persistent_connection(uri)
    ::Faraday.new(url: uri, request: request_options) do |faraday|
      # pool_size defaults to 1: we already cache one Faraday connection per
      # (thread, uri), and Net::HTTP is not thread-safe — so a single socket
      # per pool is the safe default. Override only with a specific reason.
      faraday.adapter :net_http_persistent, pool_size: @keep_alive_pool_size do |http|
        http.idle_timeout = @keep_alive_idle_timeout_seconds
      end
      @faraday_configurer.call(faraday) if @faraday_configurer
    end
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
      response_hash[:response] = "success"
      body = JSON.parse(body) unless body.empty?
      response_hash[:canonical_ids] = build_canonical_ids(body, registration_ids) unless registration_ids.empty?
      unless registration_ids.empty?
        response_hash[:not_registered_ids] =
          build_not_registered_ids(body, registration_ids)
      end
    when 400
      response_hash[:response] =
        "Only applies for JSON requests. Indicates that the request could not be parsed as JSON, " \
        "or it contained invalid fields."
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
    if !body.empty? && body["canonical_ids"].positive?
      body["results"].each_with_index do |result, index|
        canonical_ids << { old: registration_ids[index], new: result["registration_id"] } if has_canonical_id?(result)
      end
    end
    canonical_ids
  end

  def build_not_registered_ids(body, registration_id)
    not_registered_ids = []
    if !body.empty? && body["failure"].positive?
      body["results"].each_with_index do |result, index|
        not_registered_ids << registration_id[index] if is_not_registered?(result)
      end
    end
    not_registered_ids
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
      /(topics|in|\s|\(|\)|(&&)|!|(\|\|)|'([a-zA-Z0-9\-_.~%]+)')/,
      ""
    )
    bad_characters.empty?
  end

  def validate_condition_topics?(condition)
    topics = condition.scan(/(?:^|\S|\s)'([^']*?)'(?:$|\S|\s)/).flatten
    topics.all? { |topic| topic.gsub(TOPIC_REGEX, "").empty? }
  end

  def jwt_token
    scope = "https://www.googleapis.com/auth/firebase.messaging"
    @authorizer ||= Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: json_key,
      scope: scope
    )
    token = @authorizer.fetch_access_token!
    token["access_token"]
  end

  def raise_credentials_error(param)
    error_msg = "credentials must be an IO-like " \
                "object or path. You passed"

    param_klass = param.nil? ? "nil" : "a #{param.class.name}"
    error_msg += " #{param_klass}."
    raise InvalidCredentialError, error_msg
  end

  def valid_json_key_path?(path)
    valid_io_object = path.respond_to?(:open)
    return true if valid_io_object && File.file?(path)

    max_path_len = 1024
    valid_path = path.is_a?(String) && path.length <= max_path_len
    valid_path && File.file?(path)
  end

  def json_key
    @json_key ||= if @json_key_path.respond_to?(:read)
                    @json_key_path
                  elsif valid_json_key_path?(@json_key_path)
                    File.open(@json_key_path)
                  else
                    raise_credentials_error(@json_key_path)
                  end
  end
end
