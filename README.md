# Firebase Cloud Messaging (FCM) for Android and iOS

[![Gem Version](https://badge.fury.io/rb/fcm.svg)](http://badge.fury.io/rb/fcm) [![Build Status](https://github.com/decision-labs/fcm/workflows/Tests/badge.svg)](https://github.com/decision-labs/fcm/actions)

The FCM gem lets your ruby backend send notifications to Android and iOS devices via [
Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/).

## Installation

    $ gem install fcm

or in your `Gemfile` just include it:

```ruby
gem 'fcm'
```

## Requirements

For Android you will need a device running 2.3 (or newer) that also have the Google Play Store app installed, or an emulator running Android 2.3 with Google APIs. iOS devices are also supported.

A version of supported Ruby, currently:
`ruby >= 2.4`

## Getting Started
To use this gem, you need to instantiate a client with your firebase credentials:

```ruby
fcm = FCM.new(
  GOOGLE_APPLICATION_CREDENTIALS_PATH,
  FIREBASE_PROJECT_ID
)
```

## About the `GOOGLE_APPLICATION_CREDENTIALS_PATH`
The `GOOGLE_APPLICATION_CREDENTIALS_PATH` is meant to contain your firebase credentials.

The easiest way to provide them is to pass here an absolute path to a file with your credentials:

```ruby
fcm = FCM.new(
  '/path/to/credentials.json',
  FIREBASE_PROJECT_ID
)
```

As per their secret nature, you might not want to have them in your repository. In that case, another supported solution is to pass a `StringIO` that contains your credentials:

```ruby
fcm = FCM.new(
  StringIO.new(ENV.fetch('FIREBASE_CREDENTIALS')),
  FIREBASE_PROJECT_ID
)

```

## Usage

## HTTP v1 API

To migrate to HTTP v1 see: https://firebase.google.com/docs/cloud-messaging/migrate-v1

```ruby
fcm = FCM.new(
  GOOGLE_APPLICATION_CREDENTIALS_PATH,
  FIREBASE_PROJECT_ID
)
message = {
  'token': "000iddqd", # send to a specific device
  # 'topic': "yourTopic",
  # 'condition': "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)",
  'data': {
    payload: {
      data: {
        id: 1
      }
    }.to_json
  },
  'notification': {
    title: notification.title_th,
    body: notification.body_th,
  },
  'android': {},
  'apns': {
    payload: {
      aps: {
        sound: "default",
        category: "#{Time.zone.now.to_i}"
      }
    }
  },
  'fcm_options': {
    analytics_label: 'Label'
  }
}

fcm.send_v1(message) # or fcm.send_notification_v1(message)
```

## Device Group Messaging

With [device group messaging](https://firebase.google.com/docs/cloud-messaging/notifications), you can send a single message to multiple instance of an app running on devices belonging to a group. Typically, "group" refers a set of different devices that belong to a single user. However, a group could also represent a set of devices where the app instance functions in a highly correlated manner. To use this feature, you will first need an initialised `FCM` class.

The maximum number of members allowed for a notification key is 20.
https://firebase.google.com/docs/cloud-messaging/android/device-group#managing_device_groups

### Generate a Notification Key for device group

Then you will need a notification key which you can create for a particular `key_name` which needs to be uniquely named per app in case you have multiple apps for the same `project_id`. This ensures that notifications only go to the intended target app. The `create` method will do this and return the token `notification_key`, that represents the device group, in the response:

`project_id` is the SENDER_ID in your cloud settings.
https://firebase.google.com/docs/cloud-messaging/concept-options#senderid

```ruby
params = { key_name: "appUser-Chris",
                project_id: "my_project_id",
                registration_ids: ["4", "8", "15", "16", "23", "42"] }
response = fcm.create(*params.values)
```

### Send to Notification device group

To send messages to device groups, use the HTTP v1 API,
Sending messages to a device group is very similar to sending messages to an individual device, using the same method to authorize send requests. Set the token field to the group notification key

```ruby
message = {
  'token': "NOTIFICATION_KEY", # send to a device group
  # ...data
}

fcm.send_v1(message)
```

### Add/Remove Registration Tokens

You can also add/remove registration Tokens to/from a particular `notification_key` of some `project_id`. For example:

```ruby
params = { key_name: "appUser-Chris",
                project_id: "my_project_id",
                notification_key:"appUser-Chris-key",
                registration_ids:["7", "3"] }
response = fcm.add(*params.values)

params = { key_name: "appUser-Chris",
                project_id: "my_project_id",
                notification_key:"appUser-Chris-key",
                registration_ids:["8", "15"] }
response = fcm.remove(*params.values)
```

## Send Messages to Topics

FCM [topic messaging](https://firebase.google.com/docs/cloud-messaging/topic-messaging) allows your app server to send a message to multiple devices that have opted in to a particular topic. Based on the publish/subscribe model, one app instance can be subscribed to no more than 2000 topics. Sending to a topic is very similar to sending to an individual device or to a user group, in the sense that you can use the `fcm.send_v1` method where the `topic` matches the regular expression `"/topics/[a-zA-Z0-9-_.~%]+"`:

```ruby
message = {
  'topic': "yourTopic", # send to a device group
  # ...data
}

fcm.send_v1(message)
```

Or you can use the `fcm.send_to_topic` helper:

```ruby
response = fcm.send_to_topic("yourTopic",
            notification: { body: "This is a FCM Topic Message!"} )
```

## Send Messages to Topics with Conditions

FCM [topic condition messaging](https://firebase.google.com/docs/cloud-messaging/android/topic-messaging#build_send_requests) to send a message to a combination of topics, specify a condition, which is a boolean expression that specifies the target topics.

```ruby
message = {
  'condition': "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)", # send to topic condition
  # ...data
}

fcm.send_v1(message)
```

Or you can use the `fcm.send_to_topic_condition` helper:

```ruby
response = fcm.send_to_topic_condition(
  "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)",
  notification: {
    body: "This is an FCM Topic Message sent to a condition!"
  }
)
```

### Sending to Multiple Topics

To send to combinations of multiple topics, require that you set a **condition** key to a boolean condition that specifies the target topics. For example, to send messages to devices that subscribed to _TopicA_ and either _TopicB_ or _TopicC_:

```
'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)
```

FCM first evaluates any conditions in parentheses, and then evaluates the expression from left to right. In the above expression, a user subscribed to any single topic does not receive the message. Likewise, a user who does not subscribe to TopicA does not receive the message. These combinations do receive it:

- TopicA and TopicB
- TopicA and TopicC

You can include up to five topics in your conditional expression, and parentheses are supported. Supported operators: `&&`, `||`, `!`. Note the usage for !:

```
!('TopicA' in topics)
```

With this expression, any app instances that are not subscribed to TopicA, including app instances that are not subscribed to any topic, receive the message.

The `send_to_topic_condition` method within this library allows you to specicy a condition of multiple topics to which to send to the data payload.

```ruby
response = fcm.send_to_topic_condition(
  "'TopicA' in topics && ('TopicB' in topics || 'TopicC' in topics)",
  notification: {
    body: "This is an FCM Topic Message sent to a condition!"
  }
)
```

## Subscribe the client app to a topic

Given a registration token and a topic name, you can add the token to the topic using the [Google Instance ID server API](https://developers.google.com/instance-id/reference/server).

```ruby
topic = "YourTopic"
registration_token= "12" # a client registration token
response = fcm.topic_subscription(topic, registration_token)
# or unsubscription
response = fcm.topic_unsubscription(topic, registration_token)
```

Or you can manage relationship maps for multiple app instances [Google Instance ID server API. Manage relationship](https://developers.google.com/instance-id/reference/server#manage_relationship_maps_for_multiple_app_instances)

```ruby
topic = "YourTopic"
registration_tokens= ["4", "8", "15", "16", "23", "42"] # an array of one or more client registration tokens
response = fcm.batch_topic_subscription(topic, registration_tokens)
# or unsubscription
response = fcm.batch_topic_unsubscription(topic, registration_tokens)
```

## Get Information about the Instance ID

Given a registration token, you can retrieve information about the token using the [Google Instance ID server API](https://developers.google.com/instance-id/reference/server).

```ruby
registration_token= "12" # a client registration token
response = fcm.get_instance_id_info(registration_token)
```

To get detailed information about the instance ID, you can pass an optional
`options` hash to the `get_instance_id_info` method:

```ruby
registration_token= "12" # a client registration token
options = { "details" => true }
response = fcm.get_instance_id_info(registration_token, options)
```

## Mobile Clients

You can find a guide to implement an Android Client app to receive notifications here: [Set up a FCM Client App on Android](https://firebase.google.com/docs/cloud-messaging/android/client).

The guide to set up an iOS app to get notifications is here: [Setting up a FCM Client App on iOS](https://firebase.google.com/docs/cloud-messaging/ios/client).

## MIT License

- Copyright (c) 2016 Kashif Rasul and Shoaib Burq. See LICENSE.txt for details.

## Many thanks to all the contributors

- [Contributors](https://github.com/spacialdb/fcm/contributors)

## Cutting a release

Update version in `fcm.gemspec` with `VERSION` and update `CHANGELOG.md`.

```bash
# set the version
# VERSION="1.0.7"
gem build fcm.gemspec
git tag -a v${VERSION} -m "Releasing version v${VERSION}"
git push origin --tags
gem push fcm-${VERSION}.gem
```
