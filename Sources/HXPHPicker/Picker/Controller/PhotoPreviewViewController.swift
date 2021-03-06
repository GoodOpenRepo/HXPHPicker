//
//  PhotoPreviewViewController.swift
//  HXPHPickerExample
//
//  Created by Silence on 2020/11/13.
//  Copyright © 2020 Silence. All rights reserved.
//

import UIKit
import Photos

protocol PhotoPreviewViewControllerDelegate: NSObjectProtocol {
    func previewViewController(_ previewController: PhotoPreviewViewController, didOriginalButton isOriginal: Bool)
    func previewViewController(_ previewController: PhotoPreviewViewController, didSelectBox photoAsset: PhotoAsset, isSelected: Bool)
}

public class PhotoPreviewViewController: BaseViewController {
    
    weak var delegate: PhotoPreviewViewControllerDelegate?
    var config : PreviewViewConfiguration!
    var currentPreviewIndex : Int = 0
    var orientationDidChange : Bool = false
    var statusBarShouldBeHidden : Bool = false
    var previewAssets : [PhotoAsset] = []
    var videoLoadSingleCell = false
    var viewDidAppear: Bool = false
    var firstLayoutSubviews: Bool = true
    var interactiveTransition: PickerInteractiveTransition?
    lazy var selectBoxControl: PhotoPickerSelectBoxView = {
        let boxControl = PhotoPickerSelectBoxView.init(frame: CGRect(x: 0, y: 0, width: config.selectBox.size.width, height: config.selectBox.size.height))
        boxControl.backgroundColor = .clear
        boxControl.config = config.selectBox
        boxControl.addTarget(self, action: #selector(didSelectBoxControlClick), for: UIControl.Event.touchUpInside)
        return boxControl
    }()
    
    
    lazy var collectionViewLayout : UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout.init()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        return layout
    }()
    
    lazy var collectionView : UICollectionView = {
        let collectionView = UICollectionView.init(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            self.automaticallyAdjustsScrollViewInsets = false
        }
        collectionView.register(PreviewPhotoViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PreviewPhotoViewCell.self))
        collectionView.register(PreviewLivePhotoViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PreviewLivePhotoViewCell.self))
        collectionView.register(PreviewVideoViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PreviewVideoViewCell.self))
        return collectionView
    }()
    var isExternalPreview: Bool = false
    var isMultipleSelect : Bool = false
    var allowLoadPhotoLibrary: Bool = true
    lazy var bottomView : PhotoPickerBottomView = {
        let bottomView = PhotoPickerBottomView.init(config: config.bottomView, allowLoadPhotoLibrary: allowLoadPhotoLibrary, isMultipleSelect: isMultipleSelect, isPreview: true, isExternalPreview: isExternalPreview) 
        bottomView.hx_delegate = self
        if config.bottomView.showSelectedView && (isMultipleSelect || isExternalPreview) {
            bottomView.selectedView.reloadData(photoAssets: pickerController!.selectedAssetArray)
        }
        if !isExternalPreview {
            bottomView.boxControl.isSelected = pickerController!.isOriginal
            bottomView.requestAssetBytes()
        }
        return bottomView
    }()
    var requestPreviewTimer: Timer?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let margin : CGFloat = 20
        let itemWidth = view.width + margin;
        collectionViewLayout.minimumLineSpacing = margin
        collectionViewLayout.itemSize = view.size
        let contentWidth = (view.width + itemWidth) * CGFloat(previewAssets.count)
        collectionView.frame = CGRect(x: -(margin * 0.5), y: 0, width: itemWidth, height: view.height)
        collectionView.contentSize = CGSize(width: contentWidth, height: view.height)
        collectionView.setContentOffset(CGPoint(x: CGFloat(currentPreviewIndex) * itemWidth, y: 0), animated: false)
        DispatchQueue.main.async {
            if self.orientationDidChange {
                let cell = self.getCell(for: self.currentPreviewIndex)
                cell?.setupScrollViewContenSize()
                self.orientationDidChange = false
            }
        }
        configBottomViewFrame()
        if firstLayoutSubviews {
            if !previewAssets.isEmpty && config.bottomView.showSelectedView && (isMultipleSelect || isExternalPreview) {
                DispatchQueue.main.async {
                    self.bottomView.selectedView.scrollTo(photoAsset: self.previewAssets[self.currentPreviewIndex], isAnimated: false)
                }
            }
            firstLayoutSubviews = false
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        isMultipleSelect = pickerController?.config.selectMode == .multiple
        allowLoadPhotoLibrary = pickerController?.config.allowLoadPhotoLibrary ?? true
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        view.clipsToBounds = true
        config = pickerController!.config.previewView
        initView()
        if pickerController?.modalPresentationStyle == .fullScreen {
            interactiveTransition = PickerInteractiveTransition.init(panGestureRecognizerFor: self, type: .pop)
        }
    }
    public override func deviceOrientationDidChanged(notify: Notification) {
        orientationDidChange = true
        let cell = getCell(for: currentPreviewIndex)
        if cell?.photoAsset.mediaSubType == .livePhoto {
            if #available(iOS 9.1, *) {
                cell?.scrollContentView.livePhotoView.stopPlayback()
            }
        }
        if config.bottomView.showSelectedView && (isMultipleSelect || isExternalPreview) {
            bottomView.selectedView.reloadSectionInset()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pickerController?.viewControllersWillAppear(self)
    }
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidAppear = true
        let cell = getCell(for: currentPreviewIndex)
        cell?.requestPreviewAsset()
        pickerController?.viewControllersDidAppear(self)
    }
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pickerController?.viewControllersWillDisappear(self)
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pickerController?.viewControllersDidDisappear(self)
    }
    public override var prefersStatusBarHidden: Bool {
        return statusBarShouldBeHidden
    }
    
    public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return pickerController?.config.statusBarStyle ?? .default
    }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) && viewDidAppear {
                configColor()
            }
        }
    }
     
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Function
extension PhotoPreviewViewController {
     
    func initView() {
        view.addSubview(collectionView)
        view.addSubview(bottomView)
        bottomView.updateFinishButtonTitle()
        if isMultipleSelect || isExternalPreview {
            if !pickerController!.config.allowSelectedTogether && pickerController!.config.maximumSelectedVideoCount == 1 &&
                pickerController!.config.selectType == .any {
                videoLoadSingleCell = true
            }
            if !isExternalPreview {
                navigationItem.rightBarButtonItem = UIBarButtonItem.init(customView: selectBoxControl)
            }else {
                var cancelItem: UIBarButtonItem
                if config.cancelType == .image {
                    let isDark = PhotoManager.isDark
                    cancelItem = UIBarButtonItem.init(image: UIImage.image(for: isDark ? config.cancelDarkImageName : config.cancelImageName), style: .done, target: self, action: #selector(didCancelItemClick))
                }else {
                    cancelItem = UIBarButtonItem.init(title: "取消".localized, style: .done, target: self, action: #selector(didCancelItemClick))
                }
                if config.cancelPosition == .left {
                    navigationItem.leftBarButtonItem = cancelItem
                }else {
                    navigationItem.rightBarButtonItem = cancelItem
                }
            }
            if !previewAssets.isEmpty {
                if currentPreviewIndex == 0  {
                    let photoAsset = previewAssets.first!
                    if config.bottomView.showSelectedView {
                        bottomView.selectedView.scrollTo(photoAsset: photoAsset)
                    }
                    if !isExternalPreview {
                        if photoAsset.mediaType == .video && videoLoadSingleCell {
                            selectBoxControl.isHidden = true
                        }else {
                            updateSelectBox(photoAsset.isSelected, photoAsset: photoAsset)
                            selectBoxControl.isSelected = photoAsset.isSelected
                        }
                    }
                    if let pickerController = pickerController, !config.bottomView.editButtonHidden {
                        if photoAsset.mediaType == .photo {
                            bottomView.editBtn.isEnabled = pickerController.config.allowEditPhoto
                        }else if photoAsset.mediaType == .video {
                            bottomView.editBtn.isEnabled = pickerController.config.allowEditVideo
                        }
                    }
                    pickerController?.previewUpdateCurrentlyDisplayedAsset(photoAsset: photoAsset, index: currentPreviewIndex)
                }
            }
        }
    }
    func configBottomViewFrame() {
        var bottomHeight: CGFloat
        if isExternalPreview {
            bottomHeight = (pickerController?.selectedAssetArray.isEmpty ?? true) ? 0 : UIDevice.bottomMargin + 70
            if !config.bottomView.showSelectedView && config.bottomView.editButtonHidden {
                if config.bottomView.editButtonHidden {
                    bottomHeight = 0
                }else {
                    bottomHeight = UIDevice.bottomMargin + 50
                }
            }
        }else {
            bottomHeight = pickerController?.selectedAssetArray.isEmpty ?? true ? 50 + UIDevice.bottomMargin : 50 + UIDevice.bottomMargin + 70
            if !config.bottomView.showSelectedView || !isMultipleSelect {
                bottomHeight = 50 + UIDevice.bottomMargin
            }
        }
        bottomView.frame = CGRect(x: 0, y: view.height - bottomHeight, width: view.width, height: bottomHeight)
    }
    func configColor() {
        view.backgroundColor = PhotoManager.isDark ? config.backgroundDarkColor : config.backgroundColor
    }
    func getCell(for item: Int) -> PhotoPreviewViewCell? {
        if previewAssets.isEmpty {
            return nil
        }
        let cell = self.collectionView.cellForItem(at: IndexPath.init(item: item, section: 0)) as? PhotoPreviewViewCell
        return cell
    }
    func setCurrentCellImage(image: UIImage?) {
        if image != nil {
            if let cell = getCell(for: currentPreviewIndex) {
                if cell.photoAsset.mediaSubType != .imageAnimated {
                    cell.cancelRequest()
                    cell.scrollContentView.imageView.image = image
                }
            }
        }
    }
    func deleteCurrentPhotoAsset() {
        if previewAssets.isEmpty || !isExternalPreview {
            return
        }
        let photoAsset = previewAssets[currentPreviewIndex]
        if let shouldDelete = pickerController?.previewShouldDeleteAsset(photoAsset: photoAsset, index: currentPreviewIndex), !shouldDelete {
            return
        }
        previewAssets.remove(at: currentPreviewIndex)
        collectionView.deleteItems(at: [IndexPath.init(item: currentPreviewIndex, section: 0)])
        bottomView.selectedView.removePhotoAsset(photoAsset: photoAsset)
        pickerController?.previewDidDeleteAsset(photoAsset: photoAsset, index: currentPreviewIndex)
        if previewAssets.isEmpty {
            didCancelItemClick()
            return
        }
        scrollViewDidScroll(collectionView)
        setupRequestPreviewTimer()
    }
    func replacePhotoAsset(at index: Int, with photoAsset: PhotoAsset) {
        previewAssets[index] = photoAsset
        collectionView.reloadItems(at: [IndexPath.init(item: index, section: 0)])
        
    }
    func addedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        if config.bottomView.showSelectedView && (isMultipleSelect || isExternalPreview) {
            bottomView.selectedView.reloadData(photoAssets: pickerController!.selectedAssetArray)
            configBottomViewFrame()
            bottomView.layoutSubviews()
            bottomView.updateFinishButtonTitle()
        }
        getCell(for: currentPreviewIndex)?.cancelRequest()
        previewAssets.insert(photoAsset, at: currentPreviewIndex)
        collectionView.insertItems(at: [IndexPath.init(item: currentPreviewIndex, section: 0)])
        collectionView.scrollToItem(at: IndexPath(item: currentPreviewIndex, section: 0), at: .centeredHorizontally, animated: false)
        scrollViewDidScroll(collectionView)
        setupRequestPreviewTimer()
    }
}
// MARK: Action
extension PhotoPreviewViewController {
    
    @objc func didCancelItemClick() {
        pickerController?.cancelCallback()
        dismiss(animated: true, completion: nil)
    }
    @objc func didSelectBoxControlClick() {
        let isSelected = !selectBoxControl.isSelected
        let photoAsset = previewAssets[currentPreviewIndex]
        var canUpdate = false
        var bottomNeedAnimated = false
        let beforeIsEmpty = pickerController!.selectedAssetArray.isEmpty
        if isSelected {
            // 选中
            if pickerController!.addedPhotoAsset(photoAsset: photoAsset) {
                canUpdate = true
                if config.bottomView.showSelectedView && isMultipleSelect {
                    bottomView.selectedView.insertPhotoAsset(photoAsset: photoAsset)
                }
                if beforeIsEmpty {
                    bottomNeedAnimated = true
                }
            }
        }else {
            // 取消选中
            _ = pickerController?.removePhotoAsset(photoAsset: photoAsset)
            if !beforeIsEmpty && pickerController!.selectedAssetArray.isEmpty {
                bottomNeedAnimated = true
            }
            if config.bottomView.showSelectedView && isMultipleSelect {
                bottomView.selectedView.removePhotoAsset(photoAsset: photoAsset)
            }
            canUpdate = true
        }
        if canUpdate {
            if config.bottomView.showSelectedView && isMultipleSelect {
                if bottomNeedAnimated {
                    UIView.animate(withDuration: 0.25) {
                        self.configBottomViewFrame()
                        self.bottomView.layoutSubviews()
                    }
                }else {
                    configBottomViewFrame()
                }
            }
            updateSelectBox(isSelected, photoAsset: photoAsset)
            selectBoxControl.isSelected = isSelected
            delegate?.previewViewController(self, didSelectBox: photoAsset, isSelected: isSelected)
            bottomView.updateFinishButtonTitle()
            selectBoxControl.layer.removeAnimation(forKey: "SelectControlAnimation")
            let keyAnimation = CAKeyframeAnimation.init(keyPath: "transform.scale")
            keyAnimation.duration = 0.3
            keyAnimation.values = [1.2, 0.8, 1.1, 0.9, 1.0]
            selectBoxControl.layer.add(keyAnimation, forKey: "SelectControlAnimation")
        }
    }
    
    func updateSelectBox(_ isSelected: Bool, photoAsset: PhotoAsset) {
        let boxWidth = config!.selectBox.size.width
        let boxHeight = config!.selectBox.size.height
        if isSelected {
            if config.selectBox.type == .number {
                let text = String(format: "%d", arguments: [photoAsset.selectIndex + 1])
                let font = UIFont.mediumPingFang(ofSize: config!.selectBox.titleFontSize)
                let textHeight = text.height(ofFont: font, maxWidth: CGFloat(MAXFLOAT))
                var textWidth = text.width(ofFont: font, maxHeight: textHeight)
                selectBoxControl.textSize = CGSize(width: textWidth, height: textHeight)
                textWidth += boxHeight * 0.5
                if textWidth < boxWidth {
                    textWidth = boxWidth
                }
                selectBoxControl.text = text
                selectBoxControl.size = CGSize(width: textWidth, height: boxHeight)
            }else {
                selectBoxControl.size = CGSize(width: boxWidth, height: boxHeight)
            }
        }else {
            selectBoxControl.size = CGSize(width: boxWidth, height: boxHeight)
        }
    }
}

// MARK: UICollectionViewDataSource
extension PhotoPreviewViewController: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return previewAssets.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photoAsset = previewAssets[indexPath.item]
        let cell: PhotoPreviewViewCell
        if photoAsset.mediaType == .photo {
            if photoAsset.mediaSubType == .livePhoto {
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PreviewLivePhotoViewCell.self), for: indexPath) as! PreviewLivePhotoViewCell
            }else {
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PreviewPhotoViewCell.self), for: indexPath) as! PreviewPhotoViewCell
            }
        }else {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PreviewVideoViewCell.self), for: indexPath) as! PreviewVideoViewCell
            let videoCell = cell as! PreviewVideoViewCell
            videoCell.videoPlayType = config.videoPlayType
        }
        cell.photoAsset = photoAsset
        cell.delegate = self
        return cell
    }
}
// MARK: UICollectionViewDelegate
extension PhotoPreviewViewController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let myCell = cell as! PhotoPreviewViewCell
        myCell.scrollContentView.startAnimatedImage()
    }
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let myCell = cell as! PhotoPreviewViewCell
        myCell.cancelRequest()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView != collectionView || orientationDidChange {
            return
        }
        let offsetX = scrollView.contentOffset.x  + (view.width + 20) * 0.5
        let viewWidth = view.width + 20
        var currentIndex = Int(offsetX / viewWidth)
        if currentIndex > previewAssets.count - 1 {
            currentIndex = previewAssets.count - 1
        }
        if currentIndex < 0 {
            currentIndex = 0
        }
        if !previewAssets.isEmpty {
            let photoAsset = previewAssets[currentIndex]
            if !isExternalPreview {
                if photoAsset.mediaType == .video && videoLoadSingleCell {
                    selectBoxControl.isHidden = true
                }else {
                    selectBoxControl.isHidden = false
                    updateSelectBox(photoAsset.isSelected, photoAsset: photoAsset)
                    selectBoxControl.isSelected = photoAsset.isSelected
                }
            }
            if !firstLayoutSubviews && config.bottomView.showSelectedView && (isMultipleSelect || isExternalPreview) {
                bottomView.selectedView.scrollTo(photoAsset: photoAsset)
            }
            if let pickerController = pickerController, !config.bottomView.editButtonHidden {
                if photoAsset.mediaType == .photo {
                    bottomView.editBtn.isEnabled = pickerController.config.allowEditPhoto
                }else if photoAsset.mediaType == .video {
                    bottomView.editBtn.isEnabled = pickerController.config.allowEditVideo
                }
            }
            pickerController?.previewUpdateCurrentlyDisplayedAsset(photoAsset: photoAsset, index: currentIndex)
        }
        self.currentPreviewIndex = currentIndex
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView != collectionView || orientationDidChange {
            return
        }
        let cell = getCell(for: currentPreviewIndex)
        cell?.requestPreviewAsset()
    }
}

// MARK: UINavigationControllerDelegate
extension PhotoPreviewViewController: UINavigationControllerDelegate{
    
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if operation == .push {
            if toVC is PhotoPreviewViewController && fromVC is PhotoPickerViewController {
                return PickerTransition.init(type: .push)
            }
        }else if operation == .pop {
            if fromVC is PhotoPreviewViewController && toVC is PhotoPickerViewController {
                let cell = getCell(for: currentPreviewIndex)
                cell?.scrollContentView.hiddenOtherSubview()
                return PickerTransition.init(type: .pop)
            }
        }
        return nil
    }
    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if let canInteration = interactiveTransition?.canInteration, canInteration {
            return interactiveTransition
        }
        return nil
    }
}
// MARK: PhotoPreviewViewCellDelegate
extension PhotoPreviewViewController: PhotoPreviewViewCellDelegate {
    func cell(singleTap cell: PhotoPreviewViewCell) {
        if navigationController == nil {
            return
        }
        let isHidden = navigationController!.navigationBar.isHidden
        statusBarShouldBeHidden = !isHidden
        if self.modalPresentationStyle == .fullScreen {
            UIApplication.shared.setStatusBarHidden(statusBarShouldBeHidden, with: .fade)
            navigationController?.setNeedsStatusBarAppearanceUpdate()
        }
        navigationController!.setNavigationBarHidden(statusBarShouldBeHidden, animated: true)
        let currentCell = getCell(for: currentPreviewIndex)
        if !statusBarShouldBeHidden {
            self.bottomView.isHidden = false
            if currentCell?.photoAsset.mediaType == .video {
                currentCell?.scrollContentView.videoView.stopPlay()
            }
        }else {
            if currentCell?.photoAsset.mediaType == .video {
                currentCell?.scrollContentView.videoView.startPlay()
            }
        }
        UIView.animate(withDuration: 0.25) {
            self.bottomView.alpha = self.statusBarShouldBeHidden ? 0 : 1
        } completion: { (finish) in
            self.bottomView.isHidden = self.statusBarShouldBeHidden
        }
    }
}

// MARK: PhotoPickerBottomViewDelegate
extension PhotoPreviewViewController: PhotoPickerBottomViewDelegate {
    
    func bottomView(didEditButtonClick bottomView: PhotoPickerBottomView) {
        let photoAsset = previewAssets[currentPreviewIndex]
        if let shouldEditAsset = pickerController?.shouldEditAsset(photoAsset: photoAsset, atIndex: currentPreviewIndex) {
            if !shouldEditAsset {
                return
            }
        }
        #if HXPICKER_ENABLE_EDITOR
        if photoAsset.mediaType == .video {
            _ = getCell(for: currentPreviewIndex)?.scrollContentView.stopVideo()
            _ = ProgressHUD.showLoadingHUD(addedTo: self.view, text: "视频获取中".localized, animated: true)
            weak var weakSelf = self
            _ = photoAsset.requestAVAsset(iCloudHandler: nil, progressHandler: nil) { (photoAsset, avAsset, info) in
                if let weakSelf = weakSelf, let config = weakSelf.pickerController?.config {
                    ProgressHUD.hideHUD(forView: weakSelf.view, animated: false)
                    let videoEditorVC = VideoEditorViewController.init(avAsset: avAsset, config: config.videoEditor)
                    videoEditorVC.delegate = weakSelf
                    weakSelf.navigationController?.pushViewController(videoEditorVC, animated: true)
                }
            } failure: { (photoAsset, info) in
                ProgressHUD.hideHUD(forView: weakSelf?.view, animated: false)
            }
        }
        #endif
    }
    func bottomView(didFinishButtonClick bottomView: PhotoPickerBottomView) {
        if previewAssets.isEmpty {
            ProgressHUD.showWarningHUD(addedTo: self.view, text: "没有可选资源".localized, animated: true, delay: 2)
            return
        }
        let photoAsset = previewAssets[currentPreviewIndex]
        if pickerController!.config.selectMode == .multiple {
            if pickerController!.selectedAssetArray.isEmpty {
                _ = pickerController?.addedPhotoAsset(photoAsset: photoAsset)
            }
            pickerController?.finishCallback()
        }else {
            pickerController?.singleFinishCallback(for: photoAsset)
        }
    }
    func bottomView(_ bottomView: PhotoPickerBottomView, didOriginalButtonClick isOriginal: Bool) {
        delegate?.previewViewController(self, didOriginalButton: isOriginal)
        pickerController?.originalButtonCallback()
    }
    func bottomView(_ bottomView: PhotoPickerBottomView, didSelectedItemAt photoAsset: PhotoAsset) {
        if previewAssets.contains(photoAsset) {
            let index = previewAssets.firstIndex(of: photoAsset) ?? 0
            if index == currentPreviewIndex {
                return
            }
            getCell(for: currentPreviewIndex)?.cancelRequest()
            collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
            setupRequestPreviewTimer()
        }else {
            bottomView.selectedView.scrollTo(photoAsset: nil)
        }
    }
    func setupRequestPreviewTimer() {
        self.requestPreviewTimer?.invalidate()
        self.requestPreviewTimer = Timer(timeInterval: 0.2, target: self, selector:#selector(delayRequestPreview) , userInfo: nil, repeats: false)
        RunLoop.main.add(self.requestPreviewTimer!, forMode: RunLoop.Mode.common)
    }
    @objc func delayRequestPreview() {
        self.getCell(for: self.currentPreviewIndex)?.requestPreviewAsset()
        self.requestPreviewTimer = nil
    }
}

#if HXPICKER_ENABLE_EDITOR
extension PhotoPreviewViewController: VideoEditorViewControllerDelegate {
        public func videoEditorViewController(_ videoEditorViewController: VideoEditorViewController, didFinish videoURL: URL) {
            let photoAsset = PhotoAsset.init(videoURL: videoURL)
            if isExternalPreview {
                replacePhotoAsset(at: currentPreviewIndex, with: photoAsset)
            }else {
                pickerController?.addedCameraPhotoAsset(photoAsset)
            }
            pickerController?.didEditAsset(photoAsset: photoAsset, atIndex: currentPreviewIndex)
        }
        public func videoEditorViewController(didCancel videoEditorViewController: VideoEditorViewController) {
            
        }
}
#endif
