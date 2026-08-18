# frozen_string_literal: true

require "spec_helper"
require "tempfile"

describe FCM do
  let(:firebase_project_id) { "test-project" }
  let(:credentials_json) do
    { type: "service_account", project_id: firebase_project_id }.to_json
  end
  let(:json_key_file) do
    Tempfile.new(["credentials", ".json"]).tap do |file|
      file.write(credentials_json)
      file.rewind
    end
  end
  let(:json_key_path) { json_key_file.path }
  let(:client) { described_class.new(json_key_path) }

  let(:mock_token) { "access_token" }
  let(:mock_headers) do
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{mock_token}"
    }
  end

  let(:client_email) do
    "83315528762cf7e0-7bbcc3aad87e0083391bc7f234d487" \
      "c8@developer.gserviceaccount.com"
  end

  let(:client_x509_cert_url) do
    "https://www.googleapis.com/robot/v1/metadata/x509/" \
      'fd6b61037dd2bb8585527679" + "-7bbcc3aad87e0083391b' \
      "c7f234d487c8%40developer.gserviceaccount.com"
  end

  let(:large_file_name) do
    "#{Array.new(1021) { "a" }.join}.txt"
  end

  let(:creds_error) do
    FCM::InvalidCredentialError
  end

  let(:json_credentials) do
    {
      type: "service_account",
      project_id: "example",
      private_key_id: "c09c4593eee53707ca9f4208fbd6fe72b29fc7ab",
      private_key: OpenSSL::PKey::RSA.new(2048).to_s,
      client_email: client_email,
      client_id: "acedc3c0a63b3562376386f0.apps.googleusercontent.com",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: client_x509_cert_url,
      universe_domain: "googleapis.com"
    }.to_json
  end

  before do
    # Mock the Google::Auth::ServiceAccountCredentials
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
      .and_return(double(fetch_access_token!: { "access_token" => mock_token }))
  end

  it "initializes" do
    expect { client }.not_to raise_error
  end

  describe "credentials path" do
    it "can be a path to a file" do
      fcm = described_class.new(json_key_path)
      expect(fcm.__send__(:json_key).class).to eq(File)
    end

    it "raises an error when passed a large path" do
      expect do
        described_class.new(large_file_name)
      end.to raise_error(creds_error)
    end

    it "can be an IO object" do
      fcm = described_class.new(StringIO.new(credentials_json))
      expect(fcm.__send__(:json_key).class).to eq(StringIO)

      temp_file = Tempfile.new("hello_world.json")
      temp_file.write(json_credentials)
      temp_file.rewind
      fcm_with_temp_file = described_class.new(temp_file)

      expect do
        fcm_with_temp_file
      end.not_to raise_error
      temp_file.close
      temp_file.unlink
    end

    it "raises an error when passed a non IO-like object" do
      expect do
        described_class.new(nil, "", {})
      end.to raise_error(creds_error, "credentials must be " \
                                      "an IO-like object or path. You passed nil.")

      expect do
        described_class.new(json_credentials, "", {})
      end.to raise_error(creds_error, "credentials must be " \
                                      "an IO-like object or path. You passed a String.")

      expect do
        described_class.new({}, "", {})
      end.to raise_error(creds_error, "credentials must be " \
                                      "an IO-like object or path. You passed a Hash.")
    end

    it "raises an error when passed a non-existent credentials file path" do
      expect do
        described_class.new("spec/fake_credentials.json", "", {})
      end.to raise_error(creds_error)
    end

    it "raises an error when passed a string of a file that does not exist" do
      expect do
        described_class.new("example.txt", "", {})
      end.to raise_error(creds_error)
    end
  end

  describe "deprecated project_name argument" do
    let(:project_name) { "explicit-project" }

    it "prefers the explicit project name over the credentials file" do
      client = silence_warnings { described_class.new(json_key_path, project_name) }
      expect(client.__send__(:firebase_project_id)).to eq(project_name)
    end

    it "keeps accepting http_options as the third argument" do
      client = silence_warnings do
        described_class.new(json_key_path, project_name, timeout: 10)
      end
      expect(client.instance_variable_get(:@http_options)).to eq(timeout: 10)
    end

    it "emits a deprecation warning when project_name is passed" do
      expect { described_class.new(json_key_path, project_name) }
        .to output(/DEPRECATION.*project_name/).to_stderr
    end

    it "does not warn when project_name is omitted" do
      expect { described_class.new(json_key_path) }.not_to output.to_stderr
    end

    it "treats a Hash in the project_name position as http_options" do
      client = described_class.new(json_key_path, timeout: 7)
      expect(client.instance_variable_get(:@http_options)).to eq(timeout: 7)
      expect(client.instance_variable_get(:@project_name)).to eq("")
    end

    it "does not warn when a Hash is passed in the project_name position" do
      expect { described_class.new(json_key_path, timeout: 7) }.not_to output.to_stderr
    end

    def silence_warnings
      original_stderr = $stderr
      $stderr = StringIO.new
      yield
    ensure
      $stderr = original_stderr
    end
  end

  describe "firebase project id extraction" do
    it "reads project_id from an IO credentials object" do
      credentials = StringIO.new({ project_id: "io-project" }.to_json)
      fcm = described_class.new(credentials)
      expect(fcm.__send__(:firebase_project_id)).to eq("io-project")
    end

    it "resolves the project id during initialization" do
      fcm = described_class.new(json_key_path)
      json_key_file.unlink
      expect(fcm.__send__(:firebase_project_id)).to eq(firebase_project_id)
    end

    it "raises MissingProjectIdError when the credentials file has no project_id" do
      credentials = StringIO.new({ type: "service_account" }.to_json)
      expect { described_class.new(credentials) }.to raise_error(FCM::MissingProjectIdError)
    end

    it "raises MissingProjectIdError when the credentials project_id is blank" do
      credentials = StringIO.new(
        { type: "service_account", project_id: "" }.to_json
      )
      expect { described_class.new(credentials) }.to raise_error(FCM::MissingProjectIdError)
    end

    it "raises InvalidCredentialError when the credentials file is not valid JSON" do
      expect { described_class.new(StringIO.new("not-json")) }
        .to raise_error(FCM::InvalidCredentialError, /not valid JSON/)
    end
  end

  describe "#send_v1 or #send_notification_v1" do
    let(:client) { described_class.new(json_key_path) }
    let(:uri) { "#{FCM::BASE_URI_V1}#{firebase_project_id}/messages:send" }
    let(:status_code) { 200 }

    let(:stub_fcm_send_v1_request) do
      stub_request(:post, uri).with(
        body: { "message" => send_v1_params }.to_json,
        headers: mock_headers
      ).to_return(
        # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
        body: "{}",
        headers: {},
        status: status_code
      )
    end

    before do
      stub_fcm_send_v1_request
    end

    shared_examples "succesfuly send notification" do
      it "sends notification of HTTP V1 using POST to FCM server" do
        client.send_v1(send_v1_params).should eq(
          response: "success", body: "{}", headers: {}, status_code: 200
        )
        stub_fcm_send_v1_request.should have_been_made.times(1)
      end
    end

    describe "send to token" do
      let(:token) { "4sdsx" }
      let(:send_v1_params) do
        {
          "token" => token,
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          },
          "data" => {
            "story_id" => "story_12345"
          },
          "android" => {
            "notification" => {
              "click_action" => "TOP_STORY_ACTIVITY",
              "body" => "Check out the Top Story"
            }
          },
          "apns" => {
            "payload" => {
              "aps" => {
                "category" => "NEW_MESSAGE_CATEGORY"
              }
            }
          }
        }
      end

      it_behaves_like "succesfuly send notification"

      it "includes all the response" do
        response = client.send_v1(send_v1_params)
        expect(response[:status_code]).to eq(status_code)
        expect(response[:response]).to eq("success")
        expect(response[:body]).to eq("{}")
        expect(response[:headers]).to eq({})
        expect(response[:canonical_ids]).to be_nil
        expect(response[:not_registered_ids]).to be_nil
      end
    end

    describe "send to multiple tokens" do
      let(:tokens) { %w[4sdsx 4sdsy] }
      let(:send_v1_params) do
        {
          "token" => tokens,
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      it_behaves_like "succesfuly send notification"
    end

    describe "send to topic" do
      let(:topic) { "news" }
      let(:send_v1_params) do
        {
          "topic" => topic,
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      it_behaves_like "succesfuly send notification"

      context "when topic is invalid" do
        let(:topic) { "/topics/news$" }

        it "raises error" do
          stub_fcm_send_v1_request.should_not have_been_requested
        end
      end
    end

    describe "send to condition" do
      let(:condition) { "'foo' in topics" }
      let(:send_v1_params) do
        {
          "condition" => condition,
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      it_behaves_like "succesfuly send notification"
    end

    describe "send to notification_key" do
      let(:notification_key) { "notification_key" }
      let(:send_v1_params) do
        {
          "notification_key" => notification_key,
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      it_behaves_like "succesfuly send notification"
    end

    context "when the credentials file has no project_id" do
      let(:credentials_json) { { type: "service_account" }.to_json }
      let(:send_v1_params) do
        {
          "token" => "4sdsx",
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      it "raises MissingProjectIdError instead of silently skipping the send" do
        expect { client.send_v1(send_v1_params) }
          .to raise_error(FCM::MissingProjectIdError)
        stub_fcm_send_v1_request.should_not have_been_requested
      end
    end

    describe "error handling" do
      let(:send_v1_params) do
        {
          "token" => "4sdsx",
          "notification" => {
            "title" => "Breaking News",
            "body" => "New news story available."
          }
        }
      end

      context "when status_code is 400" do
        let(:status_code) { 400 }

        it "raises error" do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include("Only applies for JSON requests")
        end
      end

      context "when status_code is 401" do
        let(:status_code) { 401 }

        it "raises error" do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include("There was an error authenticating")
        end
      end

      context "when status_code is 500" do
        let(:status_code) { 500 }

        it "raises error" do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include("There was an internal error")
        end
      end

      context "when status_code is 503" do
        let(:status_code) { 503 }

        it "raises error" do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include("Server is temporarily unavailable")
        end
      end
    end
  end

  describe "#send_to_topic" do
    let(:client) { described_class.new(json_key_path) }

    let(:uri) { "#{FCM::BASE_URI_V1}#{firebase_project_id}/messages:send" }

    let(:topic) { "news" }
    let(:params) do
      {
        "topic" => topic
      }.merge(options)
    end
    let(:options) do
      {
        "data" => {
          "story_id" => "story_12345"
        }
      }
    end

    let(:stub_fcm_send_to_topic_request) do
      stub_request(:post, uri).with(
        body: { "message" => params }.to_json,
        headers: mock_headers
      ).to_return(
        body: "{}",
        headers: {},
        status: 200
      )
    end

    before do
      stub_fcm_send_to_topic_request
    end

    it "sends notification to topic using POST to FCM server" do
      client.send_to_topic(topic, options).should eq(
        response: "success", body: "{}", headers: {}, status_code: 200
      )
      stub_fcm_send_to_topic_request.should have_been_made.times(1)
    end

    context "when topic is invalid" do
      let(:topic) { "/topics/news$" }

      it "raises error" do
        client.send_to_topic(topic, options)
        stub_fcm_send_to_topic_request.should_not have_been_requested
      end
    end
  end

  describe "#send_to_topic_condition" do
    let(:client) { described_class.new(json_key_path) }

    let(:uri) { "#{FCM::BASE_URI_V1}#{firebase_project_id}/messages:send" }

    let(:topic_condition) { "'foo' in topics" }
    let(:params) do
      {
        "condition" => topic_condition
      }.merge(options)
    end
    let(:options) do
      {
        "data" => {
          "story_id" => "story_12345"
        }
      }
    end

    let(:stub_fcm_send_to_topic_condition_request) do
      stub_request(:post, uri).with(
        body: { "message" => params }.to_json,
        headers: mock_headers
      ).to_return(
        body: "{}",
        headers: {},
        status: 200
      )
    end

    before do
      stub_fcm_send_to_topic_condition_request
    end

    it "sends notification to topic_condition using POST to FCM server" do
      client.send_to_topic_condition(topic_condition, options).should eq(
        response: "success", body: "{}", headers: {}, status_code: 200
      )
      stub_fcm_send_to_topic_condition_request.should have_been_made.times(1)
    end

    context "when topic_condition is invalid" do
      let(:topic_condition) { "'foo' in topics$" }

      it "raises error" do
        client.send_to_topic_condition(topic_condition, options)
        stub_fcm_send_to_topic_condition_request.should_not have_been_requested
      end
    end
  end

  describe "#get_instance_id_info" do
    subject(:get_info) { client.get_instance_id_info(registration_token, options) }

    let(:options) { nil }
    let(:base_uri) { "#{FCM::INSTANCE_ID_API}/iid/info" }
    let(:uri) { "#{base_uri}/#{registration_token}" }
    let(:registration_token) { "42" }

    context "without options" do
      it "calls info endpoint" do
        endpoint = stub_request(:get, uri).with(headers: mock_headers)
        get_info
        expect(endpoint).to have_been_requested
      end
    end

    context "with detail option" do
      let(:uri) { "#{base_uri}/#{registration_token}?details=true" }
      let(:options) { { details: true } }

      it "calls info endpoint" do
        endpoint = stub_request(:get, uri).with(headers: mock_headers)
        get_info
        expect(endpoint).to have_been_requested
      end
    end
  end

  describe "topic subscriptions" do
    let(:topic) { "news" }
    let(:registration_token) { "42" }
    let(:registration_token2) { "43" }
    let(:registration_tokens) { [registration_token, registration_token2] }

    describe "#topic_subscription" do
      subject(:subscribe) { client.topic_subscription(topic, registration_token) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1/#{registration_token}/rel/topics/#{topic}" }

      it "subscribes to a topic" do
        endpoint = stub_request(:post, uri).with(headers: mock_headers)
        subscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#topic_unsubscription" do
      subject(:unsubscribe) { client.topic_unsubscription(topic, registration_token) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchRemove" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: [registration_token] } }

      it "unsubscribes from a topic" do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        unsubscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#batch_topic_subscription" do
      subject(:batch_subscribe) { client.batch_topic_subscription(topic, registration_tokens) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchAdd" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: registration_tokens } }

      it "subscribes to a topic" do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        batch_subscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#batch_topic_unsubscription" do
      subject(:batch_unsubscribe) { client.batch_topic_unsubscription(topic, registration_tokens) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchRemove" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: registration_tokens } }

      it "unsubscribes from a topic" do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        batch_unsubscribe
        expect(endpoint).to have_been_requested
      end
    end
  end

  describe "keep_alive_connections" do
    let(:client) { described_class.new(json_key_path, keep_alive_connections: true) }
    let(:uri) { "#{FCM::BASE_URI_V1}#{firebase_project_id}/messages:send" }
    let(:send_v1_params) { { "token" => "token", "notification" => { "title" => "hi" } } }

    before do
      stub_request(:post, uri).to_return(body: "{}", headers: {}, status: 200)
    end

    it "caches a Faraday connection per (thread, uri) and reuses it across calls" do
      client.send_v1(send_v1_params)
      first = client.__send__(:thread_connections)[FCM::BASE_URI_V1]

      client.send_v1(send_v1_params)
      second = client.__send__(:thread_connections)[FCM::BASE_URI_V1]

      expect(first).to be_a(Faraday::Connection)
      expect(second).to equal(first)
    end

    it "discards the cached connection when a request raises" do
      client.send_v1(send_v1_params)
      expect(client.__send__(:thread_connections)[FCM::BASE_URI_V1]).to be_a(Faraday::Connection)

      stub_request(:post, uri).to_raise(Faraday::ConnectionFailed.new("boom"))

      expect { client.send_v1(send_v1_params) }.to raise_error(Faraday::ConnectionFailed)
      expect(client.__send__(:thread_connections)).not_to have_key(FCM::BASE_URI_V1)
    end

    it "does not share connections across FCM instances" do
      other_client = described_class.new(json_key_path, keep_alive_connections: true)
      allow(other_client).to receive(:json_key)

      client.send_v1(send_v1_params)
      other_client.send_v1(send_v1_params)

      expect(client.__send__(:thread_connections)[FCM::BASE_URI_V1])
        .not_to equal(other_client.__send__(:thread_connections)[FCM::BASE_URI_V1])
    end

    it "falls back to one-shot connections when disabled" do
      one_shot_client = described_class.new(json_key_path)
      allow(one_shot_client).to receive(:json_key)
      one_shot_client.send_v1(send_v1_params)

      expect(one_shot_client.__send__(:thread_connections)).to be_empty
    end
  end

  describe "request timeouts" do
    it "defaults timeout and open_timeout to DEFAULT_TIMEOUT" do
      fcm = described_class.new(json_key_path)
      allow(fcm).to receive(:json_key)

      fcm.__send__(:for_uri, FCM::BASE_URI_V1) do |conn|
        expect(conn.options.timeout).to eq(FCM::DEFAULT_TIMEOUT)
        expect(conn.options.open_timeout).to eq(FCM::DEFAULT_TIMEOUT)
      end
    end

    it "honours :timeout and :open_timeout from http_options" do
      fcm = described_class.new(json_key_path, timeout: 7, open_timeout: 3)
      allow(fcm).to receive(:json_key)

      fcm.__send__(:for_uri, FCM::BASE_URI_V1) do |conn|
        expect(conn.options.timeout).to eq(7)
        expect(conn.options.open_timeout).to eq(3)
      end
    end

    it "honours :timeout and :open_timeout on keep-alive connections" do
      fcm = described_class.new(
        json_key_path, keep_alive_connections: true, timeout: 7, open_timeout: 3
      )
      allow(fcm).to receive(:json_key)

      fcm.__send__(:for_uri, FCM::BASE_URI_V1) do |conn|
        expect(conn.options.timeout).to eq(7)
        expect(conn.options.open_timeout).to eq(3)
      end
    end
  end
end
