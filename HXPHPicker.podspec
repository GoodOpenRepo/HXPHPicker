Pod::Spec.new do |spec|
    spec.name                   = "HXPHPicker"
    spec.version                = "1.0.3"
    spec.summary                = "Photo selector - Support LivePhoto, GIF selection"
    spec.homepage               = "https://github.com/SilenceLove/HXPHPicker"
    spec.license                = { :type => "MIT", :file => "LICENSE" }
    spec.author                 = { "SilenceLove" => "294005139@qq.com" }
    spec.swift_versions         = ['5.3']
    spec.ios.deployment_target  = "9.0"
    spec.source                 = { :git => "https://github.com/SilenceLove/HXPHPicker.git", :tag => "#{spec.version}" }
    spec.framework              = 'UIKit','Photos','PhotosUI'
    spec.requires_arc           = true
    
    spec.default_subspec        = 'Core', 'Picker'
  
    spec.subspec 'Core' do |core|
        core.source_files   = "Sources/HXPHPicker/Core/**/*.{swift}"
        core.resources      = "Sources/HXPHPicker/Resources/*.{bundle}"
    end
  
    spec.subspec 'Picker' do |picker|
        picker.source_files   = "Sources/HXPHPicker/Picker/**/*.{swift}"
        picker.dependency 'HXPHPicker/Core'
    end
end
