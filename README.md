# BAAppSession

[![CI Status](https://img.shields.io/travis/BenArvin/BAAppSession.svg?style=flat)](https://travis-ci.org/BenArvin/BAAppSession)
[![Version](https://img.shields.io/cocoapods/v/BAAppSession.svg?style=flat)](https://cocoapods.org/pods/BAAppSession)
[![License](https://img.shields.io/cocoapods/l/BAAppSession.svg?style=flat)](https://cocoapods.org/pods/BAAppSession)
[![Platform](https://img.shields.io/cocoapods/p/BAAppSession.svg?style=flat)](https://cocoapods.org/pods/BAAppSession)

BAAppSession is an iOS Cocoa library for communicating between processes, with HTTP style API, based on GCDAsyncSocket.

## Features

- [x] selfdefine connection port
- [x] listening connect/disconnect event
- [x] send request from client, and response it from server
- [x] boardcast message to all client, or push messge to specified client

## Installation

BAAppSession is available through CocoaPods. To install it, simply add the following line to your Podfile:

```
# pod library for client
pod 'BAAppSessionClient'

# pod library for server
pod 'BAAppSessionServer'
```

## Author

BenArvin, benarvin93@outlook.com

## License

BAAppSession is available under the MIT license. See the LICENSE file for more info.
