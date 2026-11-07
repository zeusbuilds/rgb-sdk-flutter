require 'json'

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Validate Flutter integration through `tool/test_clean_consumer_matrix.sh`.
# `pod lib lint` resolves the stale public Flutter pod and does not represent
# the pinned Flutter toolchain required by this package.
#
Pod::Spec.new do |s|
  baseline_path = File.expand_path('../tool/release_baseline.json', __dir__)
  baseline = JSON.parse(File.read(baseline_path))
  rln_version = baseline.fetch('rln').fetch('version')
  ios_requirements = baseline.fetch('buildRequirements').fetch('ios')

  # Flutter installs plugins with :path, which skips CocoaPods prepare_command.
  # Prepare before CocoaPods collects source globs; keep pod ipc spec stdout JSON.
  artifact_script = File.expand_path('../tool/download_rln_ios.sh', __dir__)
  unless system('bash', artifact_script, :out => $stderr, :err => $stderr)
    raise 'Failed to prepare verified iOS RLN artifacts. See the artifact diagnostics above.'
  end

  rgb_lib_script = File.expand_path('../tool/install_rgb_lib_ios.py', __dir__)
  unless system('python3', rgb_lib_script, :out => $stderr, :err => $stderr)
    raise 'Failed to prepare verified iOS RGB Lib artifacts. See the artifact diagnostics above.'
  end

  s.name             = 'rgb_sdk_flutter'
  s.version          = '0.2.0-beta.3'
  s.summary          = 'Flutter SDK bridge for Bitcoin RGB Protocol and RGB Lightning Node.'
  s.description      = <<-DESC
Flutter SDK bridge for Bitcoin RGB Protocol and RGB Lightning Node. This
package verifies its RGB Lib and legacy RLN native artifacts against the
SDK release pins.
Pinned RLN artifact: #{rln_version}.
                       DESC
  s.homepage         = 'https://github.com/UTEXO-Protocol/flutter-sdk'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'UTEXO Protocol' => 'https://github.com/UTEXO-Protocol' }
  s.source           = { :path => '.' }
  s.source_files = [
    'Classes/**/*',
    'RGBLightningNode.swift',
    'RGBLightningNodeFFI.h'
  ]
  s.public_header_files = 'RGBLightningNodeFFI.h'
  s.vendored_frameworks = [
    'RgbLibBindings/RGBLib.xcframework',
    'RgbLibBindings/rgb_libFFI.xcframework'
  ]
  s.preserve_paths = [
    'RGBLightningNode.xcframework',
    'RGBLightningNode.swift',
    'RGBLightningNodeFFI.h',
    'RGBLightningNodeFFI.modulemap'
  ]
  s.dependency 'Flutter'
  s.platform = :ios, ios_requirements.fetch('minimumOsVersion')

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'IPHONEOS_DEPLOYMENT_TARGET' => ios_requirements.fetch('minimumOsVersion'),
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'HEADER_SEARCH_PATHS[sdk=iphoneos*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64/Headers',
    'HEADER_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator/Headers',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64',
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator',
    'OTHER_LDFLAGS' => '$(inherited) -l"rgb_lightning_node"'
  }
  s.user_target_xcconfig = {
    'IPHONEOS_DEPLOYMENT_TARGET' => ios_requirements.fetch('minimumOsVersion'),
    'HEADER_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_ROOT)/../.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework/ios-arm64/Headers"',
    'HEADER_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited) "$(PODS_ROOT)/../.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator/Headers"'
  }
  s.swift_version = ios_requirements.fetch('swiftLanguageVersion')

  s.resource_bundles = {
    'rgb_sdk_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end
