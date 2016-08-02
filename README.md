# Firebase Cloud Messaging (FCM) for Android and iOS
[![Gem Version](https://badge.fury.io/rb/fcm.svg)](http://badge.fury.io/rb/fcm) [![Build Status](https://secure.travis-ci.org/spacialdb/fcm.png?branch=master)](http://travis-ci.org/spacialdb/fcm)

The FCM gem lets your ruby backend send notifications to Android and iOS devices via [
Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging/).

##Installation

    $ gem install fcm

or in your `Gemfile` just include it:

```ruby
gem 'fcm'
```

##Requirements

For Android you will need a device running 2.3 (or newer) that also have the Google Play Store app installed, or an emulator running Android 2.3 with Google APIs. iOS devices are also supported.

One of the following, tested Ruby versions:

* `2.0.0`
* `2.1.9`
* `2.2.5`
* `2.3.1`

##Usage

For your server to send a message to one or more devices, you must first initialise a new `FCM` class with your Firebase server Api key, and then call the `send` method on this and give it 1 or more (up to 1000) registration tokens as an array of strings. You can also optionally send further [HTTP message parameters](https://firebase.google.com/docs/cloud-messaging/http-server-ref) like `data` or `time_to_live` etc. as a hash via the second optional argument to `send`.

Example sending notifications:

```ruby
require 'fcm'

fcm = FCM.new("my_api_key")
# you can set option parameters in here
#  - all options are pass to HTTParty method arguments
#  - ref: https://github.com/jnunemaker/httparty/blob/master/lib/httparty.rb#L29-L60
#  fcm = FCM.new("my_api_key", timeout: 3)

registration_ids= ["12", "13"] # an array of one or more client registration tokens
options = {data: {score: "123"}, collapse_key: "updated_score"}
response = fcm.send(registration_ids, options)
```

Currently `response` is just a hash containing the response `body`, `headers` and `status`. Check [here](https://firebase.google.com/docs/cloud-messaging/server#response) to see how to interpret the responses.

## Device Group Messaging

With [device group messaging](https://firebase.google.com/docs/cloud-messaging/notifications), you can send a single message to multiple instance of an app running on devices belonging to a group. Typically, "group" refers a set of different devices that belong to a single user. However, a group could also represent a set of devices where the app instance functions in a highly correlated manner. To use this feature, you will first need an initialised `FCM` class.

### Generate a Notification Key for device group
Then you will need a notification key which you can create for a particular `key_name` which needs to be uniquely named per app in case you have multiple apps for the same `project_id`.  This ensures that notifications only go to the intended target app. The `create` method will do this and return the token `notification_key`, that represents the device group, in the response:

```ruby
response = fcm.create(key_name: "appUser-Chris",
                project_id: "my_project_id",
                registration_ids: ["4", "8", "15", "16", "23", "42"])
```

### Send to Notification Key
Now you can send a message to a particular `notification_key` via the `send_with_notification_key` method. This allows the server to send a single [data](https://firebase.google.com/docs/cloud-messaging/concept-options#data_messages) payload or/and [notification](https://firebase.google.com/docs/cloud-messaging/concept-options#notifications) payload to multiple app instances (typically on multiple devices) owned by a single user (instead of sending to some registration tokens). Note: the maximum number of members allowed for a `notification_key` is 20.

```ruby
response = fcm.send_with_notification_key("notification_key",
            data: {score: "3x1"},
            collapse_key: "updated_score")
```

### Add/Remove Registration Tokens

You can also add/remove registration Tokens to/from a particular `notification_key` of some `project_id`. For example:

```ruby
response = fcm.add(key_name: "appUser-Chris",
                project_id: "my_project_id",
                notification_key:"appUser-Chris-key",
                registration_ids:["7", "3"])

response = fcm.remove(key_name: "appUser-Chris",
                project_id: "my_project_id",
                notification_key:"appUser-Chris-key",
                registration_ids:["8", "15"])
```

## Send Messages to Topics

FCM [topic messaging](https://firebase.google.com/docs/cloud-messaging/topic-messaging) allows your app server to send a message to multiple devices that have opted in to a particular topic. Based on the publish/subscribe model, topic messaging supports unlimited subscriptions per app. Sending to a topic is very similar to sending to an individual device or to a user group, in the sense that you can use the `fcm.send_with_notification_key()` method where the `noticiation_key` matches the regular expression `"/topics/[a-zA-Z0-9-_.~%]+"`:

```ruby
response = fcm.send_with_notification_key("/topics/yourTopic",
            data: {message: "This is a FCM Topic Message!")
```

Or you can use the helper:

```ruby
response = fcm.send_to_topic("yourTopic",
            data: {message: "This is a FCM Topic Message!")
```

## Mobile Clients

You can find a guide to implement an Android Client app to receive notifications here: [Set up a FCM Client App on Android](https://firebase.google.com/docs/cloud-messaging/android/client).

The guide to set up an iOS app to get notifications is here: [Setting up a FCM Client App on iOS](https://firebase.google.com/docs/cloud-messaging/ios/client).

## ChangeLog

### 0.0.2

* Fixed group messaging url.
* Added API to `recover_notification_key`.

### 0.0.1

* Initial version.

##MIT License

* Copyright (c) 2016 Kashif Rasul and Shoaib Burq. See LICENSE.txt for details.

##Many thanks to all the contributors

* [Contributors](https://github.com/spacialdb/fcm/contributors)

## Donations
We accept tips through [Gratipay](https://gratipay.com/spacialdb/).

[![Gratipay](https://img.shields.io/gratipay/spacialdb.svg)](https://www.gittip.com/spacialdb/)
