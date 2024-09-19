## ChangeLog

### 2.0.0
#### Breaking Changes
- Remove deprecated `API_KEY`
- Remove deprecated `send` method
- Remove deprecated `send_with_notification_key` method
- Remove `subscribe_instance_id_to_topic` method
- Remove `unsubscribe_instance_id_from_topic` method
- Remove `batch_subscribe_instance_ids_to_topic` method
- Remove `batch_unsubscribe_instance_ids_from_topic` method

#### Supported Features
- Add HTTP v1 API support for `send_to_topic_condition` method
- Add HTTP v1 API support for `send_to_topic` method

### 1.0.8
- caches calls to `Google::Auth::ServiceAccountCredentials` #103
- Allow `faraday` versions from 1 up to 2  #101

### 1.0.7

- Fix passing `DEFAULT_TIMEOUT` to `faraday` [#96](https://github.com/decision-labs/fcm/pull/96)
- Fix issue with `get_instance_id_info` option params [#98](https://github.com/decision-labs/fcm/pull/98)
- Accept any IO object for credentials [#95](https://github.com/decision-labs/fcm/pull/94)

Huge thanks to @excid3 @jsparling @jensljungblad

### 1.0.3

- Fix overly strict faraday dependency

### 1.0.2

- Bug fix: retrieve notification key" params: https://github.com/spacialdb/fcm/commit/b328a75c11d779a06d0ceda83527e26aa0495774

### 1.0.0

- Bumped supported ruby to `>= 2.4`
- Fix deprecation warnings from `faraday` by changing dependency version to `faraday 1.0.0`

### 0.0.7

- replace `httparty` with `faraday`

### 0.0.2

- Fixed group messaging url.
- Added API to `recover_notification_key`.


### 0.0.1

- Initial version.
