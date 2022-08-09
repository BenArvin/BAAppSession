#
# Be sure to run `pod lib lint BAAppSession.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BAAppSessionServer'
  s.version          = '0.1.3'
  s.summary          = 'Server of BAAppSession'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Server of BAAppSession
                       DESC

  s.homepage         = 'https://github.com/BenArvin/BAAppSession'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'BenArvin' => 'benarvin93@outlook.com' }
  s.source           = { :git => 'https://github.com/BenArvin/BAAppSession.git', :tag => "s-#{s.version.to_s}" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform = :ios
  s.ios.deployment_target = '9.0'

  s.source_files = 'Server/Classes/**/*.{h,m}'
  
  # s.resource_bundles = {
  #   'BAAppSession' => ['BAAppSession/Assets/*.png']
  # }

  s.public_header_files = 'Classes/BAAppSessionServer.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
