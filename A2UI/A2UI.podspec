Pod::Spec.new do |s|
  s.name         = 'A2UI'
  s.version      = '0.1.0'
  s.summary      = 'A2UI Protocol v0.9 iOS UIKit implementation'
  s.description  = <<-DESC
    A native iOS UIKit framework that implements the A2UI (Agent-to-UI) Protocol v0.9.
    Provides dynamic UI rendering driven by structured JSON messages, with a reactive
    data binding system based on Combine, a composable component catalog, and a pluggable
    transport layer abstraction.
  DESC
  s.homepage     = 'https://a2ui.org'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'A2UI' => 'dev@a2ui.org' }
  s.source       = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.swift_version = '5.9'

  s.source_files = 'Sources/A2UI/**/*.swift'
  s.frameworks   = 'UIKit', 'Combine', 'Foundation', 'AVFoundation'
end
