//
//  PickerConfiguration.swift
//  照片选择器-Swift
//
//  Created by Silence on 2020/11/9.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit

open class PickerConfiguration: BaseConfiguration {
    
    /// 选择的类型，控制获取系统相册资源的类型
    public var selectType : SelectType = .any
    
    /// 选择模式
    public var selectMode: SelectMode = .multiple
    
    /// 照片和视频可以一起选择
    public var allowSelectedTogether: Bool = true
    
    /// 允许加载系统照片库
    public var allowLoadPhotoLibrary: Bool = true
    
    /// 相册展示模式
    public var albumShowMode: AlbumShowMode = .normal
    
    /// 获取资源列表时是否按创建时间排序
    public var creationDate: Bool = false
    
    /// 获取资源列表后是否按倒序展示
    public var reverseOrder: Bool = false
    
    /// 展示动图
    public var showImageAnimated: Bool = true
    
    /// 展示LivePhoto
    public var showLivePhoto: Bool = true
    
    /// 最多可以选择的照片数，如果为0则不限制
    public var maximumSelectedPhotoCount : Int = 0
    
    /// 最多可以选择的视频数，如果为0则不限制
    public var maximumSelectedVideoCount : Int = 0
    
    /// 最多可以选择的资源数，如果为0则不限制
    public var maximumSelectedCount: Int = 9
    
    /// 视频最大选择时长，为0则不限制
    public var maximumSelectedVideoDuration: Int = 0
    
    /// 视频最小选择时长，为0则不限制
    public var minimumSelectedVideoDuration: Int = 0
    
    /// 视频选择的最大文件大小，为0则不限制
    /// 如果限制了大小请将 photoList.cell.showDisableMask = false
    /// 限制并且显示遮罩会导致界面滑动卡顿
    public var maximumSelectedVideoFileSize: Int = 0
    
    /// 照片选择的最大文件大小，为0则不限制
    /// 如果限制了大小请将 photoList.cell.showDisableMask = false
    /// 限制并且显示遮罩会导致界面滑动卡顿 
    public var maximumSelectedPhotoFileSize: Int = 0
    
    /// 允许编辑照片，只控制按钮是否被禁用
    /// 显示编辑按钮的配置为：previewView.bottomView.editButtonHidden
    public var allowEditPhoto: Bool = false
    
    /// 允许编辑视频，只控制按钮是否被禁用
    /// 显示编辑按钮的配置为：previewView.bottomView.editButtonHidden
    public var allowEditVideo: Bool = false
    
    /// 状态栏样式
    public var statusBarStyle: UIStatusBarStyle = .default
    
    /// 半透明效果
    public var navigationBarIsTranslucent: Bool = true
    
    /// 导航控制器背景颜色
    public var navigationViewBackgroundColor: UIColor = UIColor.white
    
    /// 暗黑风格下导航控制器背景颜色
    public var navigationViewBackgroudDarkColor: UIColor = "#2E2F30".color
    
    /// 导航栏样式
    public var navigationBarStyle: UIBarStyle = .default
    
    /// 暗黑风格下导航栏样式
    public var navigationBarDarkStyle: UIBarStyle = .black
    
    /// 导航栏标题颜色
    public var navigationTitleColor: UIColor = UIColor.black
    
    /// 暗黑风格下导航栏标题颜色
    public var navigationTitleDarkColor: UIColor = UIColor.white
    
    /// TintColor
    public var navigationTintColor: UIColor?
    
    /// 暗黑风格下TintColor
    public var navigationDarkTintColor: UIColor = UIColor.white
    
    /// 相册列表配置
    public lazy var albumList : AlbumListConfiguration = {
        return AlbumListConfiguration.init()
    }()
    
    /// 照片列表配置
    public lazy var photoList: PhotoListConfiguration = {
        return PhotoListConfiguration.init()
    }()
    
    /// 预览界面配置
    public lazy var previewView: PreviewViewConfiguration = {
        return PreviewViewConfiguration.init()
    }()

    #if HXPICKER_ENABLE_EDITOR
    /// 视频编辑配置
    public lazy var videoEditor: VideoEditorConfiguration = .init()
    #endif
    
    /// 未授权提示界面相关配置
    public lazy var notAuthorized : NotAuthorizedConfiguration = {
        return NotAuthorizedConfiguration.init()
    }()
}
