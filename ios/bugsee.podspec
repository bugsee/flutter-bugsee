Pod::Spec.new do |s|
  s.name             = 'bugsee'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://www.bugsee.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bugsee' => 'support@bugsee.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Bugsee'
  
  s.ios.deployment_target = '8.0'
end

