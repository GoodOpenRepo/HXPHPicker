//
//  BaseConfiguration.swift
//  HXPHPicker
//
//  Created by Slience on 2021/1/8.
//

import Foundation

open class BaseConfiguration: NSObject {
    
    /// 如果自带的语言不够，可以添加自定义的语言文字
    /// PhotoManager.shared.customLanguages 自定义语言数组
    /// PhotoManager.shared.fixedCustomLanguage 如果有多种自定义语言，可以固定显示某一种
    /// 语言类型
    public var languageType: LanguageType = .system
    
    /// 外观风格
    public var appearanceStyle: AppearanceStyle = .varied
    
    /// 隐藏状态栏
    public var prefersStatusBarHidden: Bool = false
}
