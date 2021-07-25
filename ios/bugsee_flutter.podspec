Pod::Spec.new do |s|
  s.name             = 'bugsee_flutter'
  s.version          = '1.0.5'
  s.summary          = 'Bugsee plugin for Flutter'
  s.description      = <<-DESC
Bugsee Flutter SDK.
                       DESC
  s.homepage         = 'https://www.bugsee.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bugsee' => 'support@bugsee.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Bugsee', '1.27.4'

  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '"$(inherited)" "-framework" "Flutter" "-framework" "Bugsee"' }
  s.ios.deployment_target = '8.0'
end

