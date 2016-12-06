Pod::Spec.new do |s|
	# 1
  s.name = 'UrbandManager'
  s.version = '0.0.4'
  s.ios.deployment_target = '10.0'
  s.summary = 'By far the most fantastic urband manager I have seen in my entire life. No joke.'
 
  s.description = <<-DESC
  This fantastics manager allows you to control the best smartband I have seen in my entire life.
  DESC
 
 	s.homepage = 'https://github.com/CoatlCo/UrbandManager'
  s.license = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author = { 'specktro' => 'specktro@nonull.mx' }
  s.source = { :git => 'https://github.com/CoatlCo/UrbandManager.git', :tag => "#{s.version}" }
 	
 	s.framework = "CoreBluetooth"
  s.source_files = 'UrbandManager/manager/UrbandManager.swift', 'UrbandManager/utilities/Utilities.swift'
end
