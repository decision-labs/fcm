require "spec_helper"
require 'tempfile'

describe FCM do
  let(:project_name) { 'test-project' }
  let(:json_key_path) { 'path/to/json/key.json' }
  let(:client) { FCM.new(json_key_path) }

  let(:mock_token) { "access_token" }
  let(:mock_headers) do
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{mock_token}",
    }
  end

  let(:client_email) do
    '83315528762cf7e0-7bbcc3aad87e0083391bc7f234d487' \
    'c8@developer.gserviceaccount.com'
  end

  let(:client_x509_cert_url) do
    'https://www.googleapis.com/robot/v1/metadata/x509/' \
    'fd6b61037dd2bb8585527679" + "-7bbcc3aad87e0083391b' \
    'c7f234d487c8%40developer.gserviceaccount.com'
  end

  let(:large_file_name) do
    Array.new(1021) { 'a' }.join('') + '.txt'
  end

  let(:creds_error) do
    FCM::InvalidCredentialError
  end

  let(:json_credentials) do
    {
      "type": 'service_account',
      "project_id": 'example',
      "private_key_id": 'c09c4593eee53707ca9f4208fbd6fe72b29fc7ab',
      "private_key": OpenSSL::PKey::RSA.new(2048).to_s,
      "client_email": client_email,
      "client_id": 'acedc3c0a63b3562376386f0.apps.googleusercontent.com',
      "auth_uri": 'https://accounts.google.com/o/oauth2/auth',
      "token_uri": 'https://oauth2.googleapis.com/token',
      "auth_provider_x509_cert_url": 'https://www.googleapis.com/oauth2/v1/certs',
      "client_x509_cert_url": client_x509_cert_url,
      "universe_domain": 'googleapis.com'
    }.to_json
  end

  before do
    allow(client).to receive(:json_key)

    # Mock the Google::Auth::ServiceAccountCredentials
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
      .and_return(double(fetch_access_token!: { 'access_token' => mock_token }))
  end

  it 'should initialize' do
    expect { client }.not_to raise_error
  end

  describe "credentials path" do
    it 'can be a path to a file' do
      fcm = FCM.new("README.md")
      expect(fcm.__send__(:json_key).class).to eq(File)
    end

    it 'raises an error when passed a large path' do
      expect do
        FCM.new(large_file_name).__send__(:json_key)
      end.to raise_error(creds_error)
    end

    it 'can be an IO object' do
      fcm = FCM.new(StringIO.new('hey'))
      expect(fcm.__send__(:json_key).class).to eq(StringIO)

      temp_file = Tempfile.new('hello_world.json')
      temp_file.write(json_credentials)
      fcm_with_temp_file = FCM.new(temp_file)

      expect do
        fcm_with_temp_file
      end.not_to raise_error
      temp_file.close
      temp_file.unlink
    end

    it 'raises an error when passed a non IO-like object' do
      expect do
        FCM.new(nil, '', {}).__send__(:json_key)
      end.to raise_error(creds_error, 'credentials must be' \
      ' an IO-like object or path. You passed nil.')

      expect do
        FCM.new(json_credentials, '', {}).__send__(:json_key)
      end.to raise_error(creds_error, 'credentials must be' \
      ' an IO-like object or path. You passed a String.')

      expect do
        FCM.new({}, '', {}).__send__(:json_key)
      end.to raise_error(creds_error, 'credentials must be' \
      ' an IO-like object or path. You passed a Hash.')
    end

    it 'raises an error when passed a non-existent credentials file path' do
      fcm = FCM.new('spec/fake_credentials.json', '', {})
      expect { fcm.__send__(:json_key) }.to raise_error(creds_error)
    end

    it 'raises an error when passed a string of a file that does not exist' do
      fcm = FCM.new('example.txt', '', {})
      expect { fcm.__send__(:json_key) }.to raise_error(creds_error)
    end
  end

  describe "#send_v1 or #send_notification_v1" do
    let(:client) { FCM.new(json_key_path, project_name) }

    let(:uri) { "#{FCM::BASE_URI_V1}#{project_name}/messages:send" }
    let(:status_code) { 200 }

    let(:stub_fcm_send_v1_request) do
      stub_request(:post, uri).with(
        body: { 'message' => send_v1_params }.to_json,
        headers: mock_headers
      ).to_return(
        # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
        body: "{}",
        headers: {},
        status: status_code,
      )
    end

    before do
      stub_fcm_send_v1_request
    end

    shared_examples 'succesfuly send notification' do
      it 'should send notification of HTTP V1 using POST to FCM server' do
        client.send_v1(send_v1_params).should eq(
          response: 'success', body: '{}', headers: {}, status_code: 200
        )
        stub_fcm_send_v1_request.should have_been_made.times(1)
      end
    end

    describe 'send to token' do
      let(:token) { '4sdsx' }
      let(:send_v1_params) do
        {
          'token' => token,
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          },
          'data' => {
            'story_id' => 'story_12345'
          },
          'android' => {
            'notification' => {
              'click_action' => 'TOP_STORY_ACTIVITY',
              'body' => 'Check out the Top Story'
            }
          },
          'apns' => {
            'payload' => {
              'aps' => {
                'category' => 'NEW_MESSAGE_CATEGORY'
              }
            }
          }
        }
      end

      include_examples 'succesfuly send notification'

      it 'includes all the response' do
        response = client.send_v1(send_v1_params)
        expect(response[:status_code]).to eq(status_code)
        expect(response[:response]).to eq('success')
        expect(response[:body]).to eq('{}')
        expect(response[:headers]).to eq({})
        expect(response[:canonical_ids]).to be_nil
        expect(response[:not_registered_ids]).to be_nil
      end
    end

    describe 'send to multiple tokens' do
      let(:tokens) { ['4sdsx', '4sdsy'] }
      let(:send_v1_params) do
        {
          'token' => tokens,
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          }
        }
      end

      include_examples 'succesfuly send notification'
    end

    describe 'send to topic' do
      let(:topic) { 'news' }
      let(:send_v1_params) do
        {
          'topic' => topic,
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          }
        }
      end

      include_examples 'succesfuly send notification'

      context 'when topic is invalid' do
        let(:topic) { '/topics/news$' }

        it 'should raise error' do
          stub_fcm_send_v1_request.should_not have_been_requested
        end
      end
    end

    describe 'send to condition' do
      let(:condition) { "'foo' in topics" }
      let(:send_v1_params) do
        {
          'condition' => condition,
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          },
        }
      end

      include_examples 'succesfuly send notification'
    end

    describe 'send to notification_key' do
      let(:notification_key) { 'notification_key' }
      let(:send_v1_params) do
        {
          'notification_key' => notification_key,
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          }
        }
      end

      include_examples 'succesfuly send notification'
    end

    context 'when project_name is empty' do
      let(:project_name) { '' }
      let(:send_v1_params) do
        {
          'token' => '4sdsx',
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          }
        }
      end

      it 'should not send notification' do
        client.send_v1(send_v1_params)
        stub_fcm_send_v1_request.should_not have_been_requested
      end
    end

    describe 'error handling' do
      let(:send_v1_params) do
        {
          'token' => '4sdsx',
          'notification' => {
            'title' => 'Breaking News',
            'body' => 'New news story available.'
          }
        }
      end

      context 'when status_code is 400' do
        let(:status_code) { 400 }

        it 'should raise error' do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include('Only applies for JSON requests')
        end
      end

      context 'when status_code is 401' do
        let(:status_code) { 401 }

        it 'should raise error' do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include('There was an error authenticating')
        end
      end

      context 'when status_code is 500' do
        let(:status_code) { 500 }

        it 'should raise error' do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include('There was an internal error')
        end
      end

      context 'when status_code is 503' do
        let(:status_code) { 503 }

        it 'should raise error' do
          response = client.send_v1(send_v1_params)
          expect(response[:status_code]).to eq(status_code)
          expect(response[:response]).to include('Server is temporarily unavailable')
        end
      end
    end
  end

  describe '#send_to_topic' do
    let(:client) { FCM.new(json_key_path, project_name) }

    let(:uri) { "#{FCM::BASE_URI_V1}#{project_name}/messages:send" }

    let(:topic) { 'news' }
    let(:params) do
      {
        'topic' => topic
      }.merge(options)
    end
    let(:options) do
      {
        'data' => {
          'story_id' => 'story_12345'
        }
      }
    end

    let(:stub_fcm_send_to_topic_request) do
      stub_request(:post, uri).with(
        body: { 'message' => params }.to_json,
        headers: mock_headers
      ).to_return(
        body: "{}",
        headers: {},
        status: 200,
      )
    end

    before do
      stub_fcm_send_to_topic_request
    end

    it 'should send notification to topic using POST to FCM server' do
      client.send_to_topic(topic, options).should eq(
        response: 'success', body: '{}', headers: {}, status_code: 200
      )
      stub_fcm_send_to_topic_request.should have_been_made.times(1)
    end

    context 'when topic is invalid' do
      let(:topic) { '/topics/news$' }

      it 'should raise error' do
        client.send_to_topic(topic, options)
        stub_fcm_send_to_topic_request.should_not have_been_requested
      end
    end
  end

  describe "#send_to_topic_condition" do
    let(:client) { FCM.new(json_key_path, project_name) }

    let(:uri) { "#{FCM::BASE_URI_V1}#{project_name}/messages:send" }

    let(:topic_condition) { "'foo' in topics" }
    let(:params) do
      {
        'condition' => topic_condition
      }.merge(options)
    end
    let(:options) do
      {
        'data' => {
          'story_id' => 'story_12345'
        }
      }
    end

    let(:stub_fcm_send_to_topic_condition_request) do
      stub_request(:post, uri).with(
        body: { 'message' => params }.to_json,
        headers: mock_headers
      ).to_return(
        body: "{}",
        headers: {},
        status: 200,
      )
    end

    before do
      stub_fcm_send_to_topic_condition_request
    end

    it 'should send notification to topic_condition using POST to FCM server' do
      client.send_to_topic_condition(topic_condition, options).should eq(
        response: 'success', body: '{}', headers: {}, status_code: 200
      )
      stub_fcm_send_to_topic_condition_request.should have_been_made.times(1)
    end

    context 'when topic_condition is invalid' do
      let(:topic_condition) { "'foo' in topics$" }

      it 'should raise error' do
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

    context 'without options' do
      it 'calls info endpoint' do
        endpoint = stub_request(:get, uri).with(headers: mock_headers)
        get_info
        expect(endpoint).to have_been_requested
      end
    end

    context 'with detail option' do
      let(:uri) { "#{base_uri}/#{registration_token}?details=true" }
      let(:options) { { details: true } }

      it 'calls info endpoint' do
        endpoint = stub_request(:get, uri).with(headers: mock_headers)
        get_info
        expect(endpoint).to have_been_requested
      end
    end
  end

  describe "topic subscriptions" do
    let(:topic) { 'news' }
    let(:registration_token) { "42" }
    let(:registration_token_2) { "43" }
    let(:registration_tokens) { [registration_token, registration_token_2] }

    describe "#topic_subscription" do
      subject(:subscribe) { client.topic_subscription(topic, registration_token) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1/#{registration_token}/rel/topics/#{topic}" }

      it 'subscribes to a topic' do
        endpoint = stub_request(:post, uri).with(headers: mock_headers)
        subscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#topic_unsubscription" do
      subject(:unsubscribe) { client.topic_unsubscription(topic, registration_token) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchRemove" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: [registration_token] } }

      it 'unsubscribes from a topic' do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        unsubscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#batch_topic_subscription" do
      subject(:batch_subscribe) { client.batch_topic_subscription(topic, registration_tokens) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchAdd" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: registration_tokens } }

      it 'subscribes to a topic' do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        batch_subscribe
        expect(endpoint).to have_been_requested
      end
    end

    describe "#batch_topic_unsubscription" do
      subject(:batch_unsubscribe) { client.batch_topic_unsubscription(topic, registration_tokens) }

      let(:uri) { "#{FCM::INSTANCE_ID_API}/iid/v1:batchRemove" }
      let(:params) { { to: "/topics/#{topic}", registration_tokens: registration_tokens } }

      it 'unsubscribes from a topic' do
        endpoint = stub_request(:post, uri).with(body: params.to_json, headers: mock_headers)
        batch_unsubscribe
        expect(endpoint).to have_been_requested
      end
    end
  end
end
