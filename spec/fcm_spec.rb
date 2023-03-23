# frozen_string_literal: true

require 'spec_helper'

describe FCM do
  let(:api_key) { 'AIzaSyB-1uEai2WiUapxCs2Q0GZYzPu7Udno5aA' }
  let(:fcm) { described_class.new(api_key) }
  let(:send_url) { "#{FCM::BASE_URI}/fcm/send" }
  let(:valid_condition) do
    "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)"
  end
  let(:valid_request_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "key=#{api_key}"
    }
  end
  let(:registration_id) { '42' }

  it 'raises an error if the api key is not provided' do
    expect { described_class.new }.to raise_error(ArgumentError)
  end

  describe '#send_notification' do
    let(:mock_request_attributes) do
      {
        body: valid_request_body.to_json,
        headers: valid_request_headers
      }
    end
    let(:stub_fcm_send_request) do
      stub_request(:post, send_url).with(
        mock_request_attributes
      ).to_return(
        # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
        body: '{}',
        headers: {},
        status: 200
      )
    end

    let(:valid_request_body) do
      { registration_ids: [registration_id] }
    end

    let(:successful_fcm_response) do
      {
        response: 'success',
        body: '{}',
        headers: {},
        status_code: 200,
        canonical_ids: [],
        not_registered_ids: []
      }
    end

    before { stub_fcm_send_request }

    context 'when registration_id provided as array' do
      subject(:send_notification) { fcm.send([registration_id]) }

      it 'sends notification successfully' do
        expect(send_notification).to eq(successful_fcm_response)
        stub_fcm_send_request.should have_been_requested
      end
    end

    context 'when registration_id provided as string' do
      subject(:send_notification) { fcm.send(registration_id) }

      it 'sends notification successfully' do
        expect(send_notification).to eq(successful_fcm_response)
        stub_fcm_send_request.should have_been_requested
      end
    end

    context 'when send notification with data' do
      subject(:send_notification_with_data) do
        fcm.send(
          [registration_id], data: { score: '5x1', time: '15:10' }
        )
      end

      let(:stub_request_with_data) do
        stub_request(:post, send_url)
          .with(
            body:
              '{"registration_ids":["42"],"data":{"score":"5x1","time":"15:10"}}',
            headers: valid_request_headers
          ).to_return(status: 200, body: '', headers: {})
      end

      let(:successful_fcm_response) do
        {
          response: 'success',
          body: '',
          headers: {},
          status_code: 200,
          canonical_ids: [],
          not_registered_ids: []
        }
      end

      before { stub_request_with_data }

      it 'sends the data in a post request to fcm' do
        expect(send_notification_with_data).to eq(successful_fcm_response)
        stub_request_with_data.should have_been_requested
      end
    end

    context 'with failure code 400' do
      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
          body: '{}',
          headers: {},
          status: 400
        )
      end

      it 'does not send notification due to 400' do
        fcm.send([registration_id]).should eq(
          body: '{}',
          headers: {},
          response: Fcm::Error::ERROR_RESPONSE_400,
          status_code: 400
        )
      end
    end

    context 'with failure code 401' do
      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
          body: '{}',
          headers: {},
          status: 401
        )
      end

      it 'does not send notification due to 401' do
        fcm.send([registration_id]).should eq(
          body: '{}',
          headers: {},
          response: Fcm::Error::ERROR_RESPONSE_401,
          status_code: 401
        )
      end
    end

    context 'with failure code 503' do
      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
          body: '{}',
          headers: {},
          status: 503
        )
      end

      it 'does not send notification due to 503' do
        fcm.send([registration_id]).should eq(
          body: '{}',
          headers: {},
          response: Fcm::Error::ERROR_RESPONSE_503,
          status_code: 503
        )
      end
    end

    context 'with failure code 5xx' do
      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
          body: '{"body-key" => "Body value"}',
          headers: { 'header-key' => 'Header value' },
          status: 599
        )
      end

      it 'does not send notification due to 599' do
        fcm.send([registration_id]).should eq(
          body: '{"body-key" => "Body value"}',
          headers: { 'Header-Key' => 'Header value' },
          response: Fcm::Error::ERROR_RESPONSE_50X,
          status_code: 599
        )
      end
    end

    context 'when send_notification responds canonical_ids' do
      let(:valid_response_body_with_canonical_ids) do
        {
          failure: 0, canonical_ids: 1, results: [
            {
              registration_id: '43',
              message_id: '0:1385025861956342%572c22801bb3'
            }
          ]
        }
      end

      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
          body: valid_response_body_with_canonical_ids.to_json,
          headers: {},
          status: 200
        )
      end

      it 'response body should contain canonical_ids' do
        response = fcm.send([registration_id])

        response.should eq(
          headers: {},
          canonical_ids: [{ old: '42', new: '43' }],
          not_registered_ids: [],
          status_code: 200,
          response: 'success',
          body:
            '{"failure":0,"canonical_ids":1,"results":'\
            '[{"registration_id":"43","message_id":'\
            '"0:1385025861956342%572c22801bb3"}]}'
        )
      end
    end

    context 'when send_notification responds with NotRegistered' do
      let(:valid_response_body_with_not_registered_ids) do
        {
          canonical_ids: 0, failure: 1, results: [{ error: 'NotRegistered' }]
        }
      end

      before do
        stub_request(:post, send_url).with(
          mock_request_attributes
        ).to_return(
          body: valid_response_body_with_not_registered_ids.to_json,
          headers: {},
          status: 200
        )
      end

      it 'contains not_registered_ids' do
        response = fcm.send([registration_id])
        response.should eq(
          headers: {},
          canonical_ids: [],
          not_registered_ids: [registration_id],
          status_code: 200,
          response: 'success',
          body: '{"canonical_ids":0,"failure":1,'\
          '"results":[{"error":"NotRegistered"}]}'
        )
      end
    end
  end

  describe '#send_to_topic' do
    let(:successful_fcm_response) do
      {
        response: 'success',
        body: '',
        headers: {},
        status_code: 200
      }
    end

    context 'when valid topic' do
      subject(:send_notification_to_topic) do
        fcm.send_to_topic(valid_topic, data: { score: '5x1', time: '15:10' })
      end

      let(:valid_topic) { 'TopicA' }
      let!(:stub_with_valid_topic) do
        stub_request(:post, send_url).with(
          body: '{"to":"/topics/TopicA","data":{"score":"5x1","time":"15:10"}}',
          headers: valid_request_headers
        ).to_return(status: 200, body: '', headers: {})
      end

      it 'sends the data in a post request to fcm' do
        expect(send_notification_to_topic).to eq(successful_fcm_response)
        stub_with_valid_topic.should have_been_requested
      end
    end

    context 'when invalid topic' do
      let(:invalid_topic) { 'TopicA$' }

      let!(:stub_with_invalid_topic) do
        stub_request(:post, send_url).with(
          body: '{"condition":"/topics/TopicA$",'\
          '"data":{"score":"5x1","time":"15:10"}}',
          headers: valid_request_headers
        ).to_return(status: 200, body: '', headers: {})
      end

      it 'does not send to invalid topics' do
        stub_with_invalid_topic.should_not have_been_requested
      end
    end
  end

  describe '#send_to_topic_condition' do
    context 'when sending notification to a topic condition' do
      let!(:stub_with_valid_condition) do
        stub_request(:post, send_url)
          .with(
            body: '{"condition":"\'TopicA\' in topics && (\'TopicB\' in topics'\
            ' || \'TopicC\' in topics)","data":{"score":"5x1","time":"15:10"}}',
            headers: valid_request_headers
          ).to_return(status: 200, body: '', headers: {})
      end

      it 'sends the data in a post request to fcm' do
        fcm.send_to_topic_condition(
          valid_condition,
          data: { score: '5x1', time: '15:10' }
        )
        stub_with_valid_condition.should have_been_requested
      end
    end

    context 'when sending notification to an invalid condition' do
      let!(:stub_with_invalid_condition) do
        stub_request(:post, send_url)
          .with(
            body:
              '{"condition":"\'TopicA\' in topics and some other text'\
              ' (\'TopicB\' in topics || \'TopicC\' in topics)","data":'\
              '{"score":"5x1","time":"15:10"}}',
            headers: valid_request_headers
          ).to_return(status: 200, body: '', headers: {})
      end

      let(:invalid_condition) do
        "'TopicA' in topics and some other text'\
        ' ('TopicB' in topics || 'TopicC' in topics)"
      end

      it 'does not send to invalid conditions' do
        fcm.send_to_topic_condition(invalid_condition,
                                    data: { score: '5x1', time: '15:10' })
        stub_with_invalid_condition.should_not have_been_requested
      end
    end

    context 'when sending notification to an invalid condition topic' do
      let(:invalid_condition_topic) { "'TopicA$' in topics" }
      let!(:stub_with_invalid_condition_topic) do
        stub_request(:post, send_url)
          .with(
            body:
              '{"condition":"\'TopicA$\' in topics","data"'\
              ':{"score":"5x1","time":"15:10"}}',
            headers: valid_request_headers
          ).to_return(status: 200, body: '', headers: {})
      end

      it 'does not send to invalid topics in a condition' do
        fcm.send_to_topic_condition(
          invalid_condition_topic,
          data: { score: '5x1', time: '15:10' }
        )
        stub_with_invalid_condition_topic.should_not have_been_requested
      end
    end
  end

  describe 'sending group notifications' do
    let(:group_notification_base_uri) do
      "#{FCM::GROUP_NOTIFICATION_BASE_URI}/gcm/notification"
    end
    let(:notification_key) { 'APA91bGHXQBB...9QgnYOEURwm0I3lmyqzk2TXQ' }
    let(:key_name) { 'appUser-Chris' }
    # https://developers.google.com/cloud-messaging/gcm#senderid
    let(:project_id) { '123456789' }

    let(:mock_request_attributes) do
      {
        body: valid_request_body.to_json,
        headers: valid_request_headers
      }
    end

    let(:valid_request_headers) do
      {
        'Authorization' => "key=#{api_key}",
        'Content-Type' => 'application/json',
        'Project-Id' => project_id
      }
    end
    let(:valid_response_body) do
      { notification_key: 'APA91bGHXQBB...9QgnYOEURwm0I3lmyqzk2TXQ' }
    end

    let(:default_valid_request_body) do
      {
        registration_ids: [registration_id],
        operation: 'create',
        notification_key_name: key_name
      }
    end

    # ref: https://firebase.google.com/docs/cloud-messaging/notifications#managing-device-groups-on-the-app-server
    context 'when #create_notification_key' do
      let(:valid_request_body) do
        default_valid_request_body.merge(
          operation: 'create'
        )
      end

      before do
        stub_request(:post, group_notification_base_uri).with(
          mock_request_attributes
        ).to_return(
          body: valid_response_body.to_json,
          headers: {},
          status: 200
        )
      end

      it 'sends a post request' do
        response = fcm.create(key_name, project_id, [registration_id])
        response.should eq(
          headers: {},
          status_code: 200,
          response: 'success',
          body: valid_response_body.to_json
        )
      end
    end

    context 'when #add_notification_key' do
      let(:valid_request_body) do
        default_valid_request_body.merge(
          operation: 'add',
          notification_key: notification_key
        )
      end

      before do
        stub_request(:post, group_notification_base_uri).with(
          mock_request_attributes
        ).to_return(
          body: valid_response_body.to_json,
          headers: {},
          status: 200
        )
      end

      it 'sends a post request' do
        response = fcm.add(
          key_name, project_id,
          notification_key,
          [registration_id]
        )
        response.should eq(
          headers: {},
          status_code: 200,
          response: 'success',
          body: valid_response_body.to_json
        )
      end
    end

    context 'when #remove_notification_key' do
      let(:valid_request_body) do
        default_valid_request_body.merge(
          operation: 'remove',
          notification_key: notification_key
        )
      end

      before do
        stub_request(:post, group_notification_base_uri).with(
          mock_request_attributes
        ).to_return(
          body: valid_response_body.to_json,
          headers: {},
          status: 200
        )
      end

      it 'sends a post request' do
        response = fcm.remove(
          key_name, project_id,
          notification_key,
          [registration_id]
        )
        response.should eq(
          headers: {},
          status_code: 200,
          response: 'success',
          body: valid_response_body.to_json
        )
      end
    end

    context 'when #recover_notification_key' do
      it "sends a 'retrieve notification key' request" do
        endpoint = stub_request(:get, group_notification_base_uri).with(
          headers: valid_request_headers,
          query: { notification_key_name: key_name }
        )

        fcm.recover_notification_key(key_name, project_id)

        expect(endpoint).to have_been_requested
      end
    end
  end

  describe '#get_instance_id_info' do
    subject(:get_info) { client.get_instance_id_info(registration_id, options) }

    let(:options) { nil }
    let(:client) { described_class.new(api_key) }
    let(:base_uri) { "#{FCM::INSTANCE_ID_API}/iid/info" }
    let(:uri) { "#{base_uri}/#{registration_id}" }
    let(:mock_request_attributes) do
      { headers: {
        'Authorization' => "key=#{api_key}",
        'Content-Type' => 'application/json'
      } }
    end

    context 'without options' do
      it 'calls info endpoint' do
        endpoint = stub_request(:get, uri).with(mock_request_attributes)
        get_info
        expect(endpoint).to have_been_requested
      end
    end

    context 'with detail option' do
      let(:uri) { "#{base_uri}/#{registration_id}?details=true" }
      let(:options) { { details: true } }

      it 'calls info endpoint' do
        endpoint = stub_request(:get, uri).with(mock_request_attributes)
        get_info
        expect(endpoint).to have_been_requested
      end
    end
  end

  describe 'credentials json_key_path' do
    it 'can be a path to a file' do
      fcm = described_class.new('test', 'README.md')
      expect(fcm.__send__(:json_key).class).to eq(File)
    end

    it 'can be an IO object' do
      fcm = described_class.new('test', StringIO.new('hey'))
      expect(fcm.__send__(:json_key).class).to eq(StringIO)
    end
  end

  describe '#send_v1' do
    let(:project_name) { 'project_name' }
    let(:send_v1_url) { "#{FCM::BASE_URI_V1}#{project_name}/messages:send" }
    let(:access_token) { 'access_token' }
    let(:valid_request_v1_headers) do
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{access_token}"
      }
    end

    let(:send_v1_params) do
      {
        'token' => '4sdsx',
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

    let(:google_authorizer_double) { instance_double('google_token_fetcher') }
    let(:json_key_path) { object_double('file_alike_object') }

    let(:stub_fcm_send_v1_request) do
      stub_request(:post, send_v1_url).with(
        body: { 'message' => send_v1_params }.to_json,
        headers: valid_request_v1_headers
      ).to_return(
        # ref: https://firebase.google.com/docs/cloud-messaging/http-server-ref#interpret-downstream
        body: '{}',
        headers: {},
        status: 200
      )
    end

    before do
      stub_fcm_send_v1_request
    end

    it 'sends notification of HTTP V1 using POST to FCM server' do
      allow(json_key_path).to receive(:respond_to?).and_return(true)
      allow(Google::Auth::ServiceAccountCredentials).to receive(
        :make_creds
      ).and_return(google_authorizer_double)
      allow(google_authorizer_double).to receive(
        :fetch_access_token!
      ).and_return('access_token' => access_token)

      fcm = described_class.new(api_key, json_key_path, project_name)
      fcm.send_v1(send_v1_params).should eq(
        response: 'success', body: '{}', headers: {}, status_code: 200
      )
      stub_fcm_send_v1_request.should have_been_made.times(1)
    end
  end
end
