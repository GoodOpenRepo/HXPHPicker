//
//  PhotoPickerViewController.swift
//  照片选择器-Swift
//
//  Created by Silence on 2019/6/29.
//  Copyright © 2019年 Silence. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import Photos

enum PhotoPickerViewControllerSwipeSelectState {
    case select
    case unselect
}

public class PhotoPickerViewController: BaseViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    var config: PhotoListConfiguration!
    var assetCollection: PhotoAssetCollection!
    var assets: [PhotoAsset] = []
    var swipeSelectBeganIndexPath: IndexPath?
    var swipeSelectedIndexArray: [Int]?
    var swipeSelectState: PhotoPickerViewControllerSwipeSelectState?
    lazy var collectionViewLayout: UICollectionViewFlowLayout = {
        let collectionViewLayout = UICollectionViewFlowLayout.init()
        let space = config.spacing
        collectionViewLayout.minimumLineSpacing = space
        collectionViewLayout.minimumInteritemSpacing = space
        return collectionViewLayout
    }()
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView.init(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView.dataSource = self
        collectionView.delegate = self
        if let customSingleCellClass = config.cell.customSingleCellClass {
            collectionView.register(customSingleCellClass, forCellWithReuseIdentifier: NSStringFromClass(PhotoPickerViewCell.classForCoder()))
        }else {
            collectionView.register(PhotoPickerViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PhotoPickerViewCell.classForCoder()))
        }
        if let customSelectableCellClass = config.cell.customSelectableCellClass {
            collectionView.register(customSelectableCellClass, forCellWithReuseIdentifier: NSStringFromClass(PhotoPickerSelectableViewCell.classForCoder()))
        }else {
            collectionView.register(PhotoPickerSelectableViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PhotoPickerSelectableViewCell.classForCoder()))
        }
        if config.allowAddCamera {
            collectionView.register(PickerCamerViewCell.self, forCellWithReuseIdentifier: NSStringFromClass(PickerCamerViewCell.classForCoder()))
        }
        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            self.automaticallyAdjustsScrollViewInsets = false
        }
        return collectionView
    }()
    
    var cameraCell: PickerCamerViewCell {
        get {
            var indexPath: IndexPath
            if !pickerController!.config.reverseOrder {
                indexPath = IndexPath(item: assets.count, section: 0)
            }else {
                indexPath = IndexPath(item: 0, section: 0)
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PickerCamerViewCell.classForCoder()), for: indexPath) as! PickerCamerViewCell
            cell.config = config.cameraCell
            return cell
        }
    }
    
    private lazy var emptyView: EmptyView = {
        let emptyView = EmptyView.init(frame: CGRect(x: 0, y: 0, width: view.width, height: 0))
        emptyView.config = config.emptyView
        emptyView.layoutSubviews()
        return emptyView
    }()
    
    var canAddCamera: Bool = false
    var orientationDidChange : Bool = false
    var beforeOrientationIndexPath: IndexPath?
    var showLoading : Bool = false
    var isMultipleSelect : Bool = false
    var videoLoadSingleCell = false
    var needOffset: Bool {
        get {
            return pickerController != nil && pickerController!.config.reverseOrder && config.allowAddCamera && canAddCamera
        }
    }
    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel.init()
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        return titleLabel
    }()
    lazy var titleView: AlbumTitleView = {
        let titleView = AlbumTitleView.init(config: config.titleViewConfig)
        titleView.addTarget(self, action: #selector(didTitleViewClick(control:)), for: .touchUpInside)
        return titleView
    }()
    
    lazy var albumBackgroudView: UIView = {
        let albumBackgroudView = UIView.init()
        albumBackgroudView.isHidden = true
        albumBackgroudView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        albumBackgroudView.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(didAlbumBackgroudViewClick)))
        return albumBackgroudView
    }()
    
    lazy var albumView: AlbumView = {
        let albumView = AlbumView.init(config: pickerController!.config.albumList)
        albumView.delegate = self
        return albumView
    }()
    
    lazy var bottomView : PhotoPickerBottomView = {
        let bottomView = PhotoPickerBottomView.init(config: config.bottomView, allowLoadPhotoLibrary: allowLoadPhotoLibrary)
        bottomView.hx_delegate = self
        bottomView.boxControl.isSelected = pickerController!.isOriginal
        return bottomView
    }()
    var allowLoadPhotoLibrary: Bool = true
    var swipeSelectAutoScrollTimer: DispatchSourceTimer?
    var swipeSelectPanGR: UIPanGestureRecognizer?
    var swipeSelectLastLocalPoint: CGPoint?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        allowLoadPhotoLibrary = pickerController?.config.allowLoadPhotoLibrary ?? true
        if AssetManager.authorizationStatus() == .notDetermined {
            canAddCamera = true
        }
        configData()
        initView()
        configColor()
        fetchData()
        if config.allowSwipeToSelect && pickerController!.config.selectMode == .multiple {
            swipeSelectPanGR = UIPanGestureRecognizer.init(target: self, action: #selector(panGestureRecognizer(panGR:)))
            view.addGestureRecognizer(swipeSelectPanGR!)
        }
    }
     
    public override func deviceOrientationDidChanged(notify: Notification) {
        guard #available(iOS 13.0, *) else {
            beforeOrientationIndexPath = collectionView.indexPathsForVisibleItems.first
            orientationDidChange = true
            return
        }
    }
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let margin: CGFloat = UIDevice.leftMargin
        collectionView.frame = CGRect(x: margin, y: 0, width: view.width - 2 * margin, height: view.height)
        var collectionTop: CGFloat
        if navigationController?.modalPresentationStyle == .fullScreen && UIDevice.isPortrait {
            collectionTop = UIDevice.navigationBarHeight
        }else {
            collectionTop = navigationController!.navigationBar.height
        }
        if let pickerController = pickerController {
            if pickerController.config.albumShowMode == .popup {
                albumBackgroudView.frame = view.bounds
                configAlbumViewFrame()
            }else {
                var titleWidth = titleLabel.text?.width(ofFont: titleLabel.font, maxHeight: 30) ?? 0
                if titleWidth > view.width * 0.6 {
                    titleWidth = view.width * 0.6
                }
                titleLabel.size = CGSize(width: titleWidth, height: 30)
            }
        }
        if isMultipleSelect {
            let promptHeight: CGFloat = (AssetManager.authorizationStatusIsLimited() && config.bottomView.showPrompt && allowLoadPhotoLibrary) ? 70 : 0
            let bottomHeight: CGFloat = 50 + UIDevice.bottomMargin + promptHeight
            bottomView.frame = CGRect(x: 0, y: view.height - bottomHeight, width: view.width, height: bottomHeight)
            collectionView.contentInset = UIEdgeInsets(top: collectionTop, left: 0, bottom: bottomView.height + 0.5, right: 0)
            collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomHeight - UIDevice.bottomMargin, right: 0)
        }else {
            collectionView.contentInset = UIEdgeInsets(top: collectionTop, left: 0, bottom: UIDevice.bottomMargin, right: 0)
        }
        let space = config.spacing
        let count : CGFloat
        if  UIDevice.isPortrait == true {
            count = CGFloat(config.rowNumber)
        }else {
            count = CGFloat(config.landscapeRowNumber)
        }
        let itemWidth = (collectionView.width - space * (count - CGFloat(1))) / count
        collectionViewLayout.itemSize = CGSize.init(width: itemWidth, height: itemWidth)
        if orientationDidChange {
            if pickerController != nil && pickerController!.config.albumShowMode == .popup {
                titleView.updateViewFrame()
            }
            collectionView.reloadData()
            DispatchQueue.main.async {
                if self.beforeOrientationIndexPath != nil {
                    self.collectionView.scrollToItem(at: self.beforeOrientationIndexPath!, at: .top, animated: false)
                }
            }
            orientationDidChange = false
        }
        emptyView.width = collectionView.width
        emptyView.center = CGPoint(x: collectionView.width * 0.5, y: (collectionView.height - collectionView.contentInset.top - collectionView.contentInset.bottom) * 0.5)
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pickerController?.viewControllersWillAppear(self)
    }
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if #available(iOS 13.0, *) {
            beforeOrientationIndexPath = collectionView.indexPathsForVisibleItems.first
            orientationDidChange = true
        }
        super.viewWillTransition(to: size, with: coordinator)
    }
    public override var prefersStatusBarHidden: Bool {
        return false
    }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                configColor()
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: fetch Asset
extension PhotoPickerViewController {
    
    func fetchData() {
        if pickerController!.config.albumShowMode == .popup {
            fetchAssetCollections()
            title = ""
            navigationItem.titleView = titleView
            if pickerController?.cameraAssetCollection != nil {
                assetCollection = pickerController?.cameraAssetCollection
                assetCollection.isSelected = true
                titleView.title = assetCollection.albumName
                fetchPhotoAssets()
            }else {
                weak var weakSelf = self
                pickerController?.fetchCameraAssetCollectionCompletion = { (assetCollection) in
                    var cameraAssetCollection = assetCollection
                    if cameraAssetCollection == nil {
                        cameraAssetCollection = PhotoAssetCollection.init(albumName: self.pickerController!.config.albumList.emptyAlbumName.localized, coverImage: self.pickerController!.config.albumList.emptyCoverImageName.image)
                    }
                    weakSelf?.assetCollection = cameraAssetCollection
                    weakSelf?.assetCollection.isSelected = true
                    weakSelf?.titleView.title = weakSelf?.assetCollection.albumName
                    weakSelf?.fetchPhotoAssets()
                }
            }
        }else {
            title = ""
            navigationItem.titleView = titleLabel
            if showLoading {
                _ = ProgressHUD.showLoadingHUD(addedTo: view, afterDelay: 0.15, animated: true)
            }
            fetchPhotoAssets()
        }
    }
    
    func fetchAssetCollections() {
        if !pickerController!.assetCollectionsArray.isEmpty {
            albumView.assetCollectionsArray = pickerController!.assetCollectionsArray
            albumView.currentSelectedAssetCollection = assetCollection
            configAlbumViewFrame()
        }
        fetchAssetCollectionsClosure()
        if !pickerController!.config.allowLoadPhotoLibrary {
            pickerController?.fetchAssetCollections()
        }
    }
    private func fetchAssetCollectionsClosure() {
        weak var weakSelf = self
        pickerController?.fetchAssetCollectionsCompletion = { (assetCollectionsArray) in
            weakSelf?.albumView.assetCollectionsArray = assetCollectionsArray
            weakSelf?.albumView.currentSelectedAssetCollection = weakSelf?.assetCollection
            weakSelf?.configAlbumViewFrame()
        }
    }
    func fetchPhotoAssets() {
        weak var weakSelf = self
        pickerController!.fetchPhotoAssets(assetCollection: assetCollection) { (photoAssets, photoAsset) in
            weakSelf?.canAddCamera = true
            weakSelf?.assets = photoAssets
            weakSelf?.setupEmptyView()
            weakSelf?.collectionView.reloadData()
            weakSelf?.scrollToAppropriatePlace(photoAsset: photoAsset)
            if weakSelf != nil && weakSelf!.showLoading {
                ProgressHUD.hideHUD(forView: weakSelf?.view, animated: true)
                weakSelf?.showLoading = false
            }else {
                ProgressHUD.hideHUD(forView: weakSelf?.navigationController?.view, animated: false)
            }
        }
    }
}

// MARK: Function
extension PhotoPickerViewController {
    
    func initView() {
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        view.addSubview(collectionView)
        if isMultipleSelect {
            view.addSubview(bottomView)
            bottomView.updateFinishButtonTitle()
        }
        if pickerController!.config.albumShowMode == .popup {
            var cancelItem: UIBarButtonItem
            if config.cancelType == .text {
                cancelItem = UIBarButtonItem.init(title: "取消".localized, style: .done, target: self, action: #selector(didCancelItemClick))
            }else {
                cancelItem = UIBarButtonItem.init(image: UIImage.image(for: PhotoManager.isDark ? config.cancelDarkImageName : config.cancelImageName), style: .done, target: self, action: #selector(didCancelItemClick))
            }
            if config.cancelPosition == .left {
                navigationItem.leftBarButtonItem = cancelItem
            }else {
                navigationItem.rightBarButtonItem = cancelItem
            }
            view.addSubview(albumBackgroudView)
            view.addSubview(albumView)
        }else {
            navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "取消".localized, style: .done, target: self, action: #selector(didCancelItemClick))
        }
    }
    func configData() {
        isMultipleSelect = pickerController!.config.selectMode == .multiple
        if !pickerController!.config.allowSelectedTogether && pickerController!.config.maximumSelectedVideoCount == 1 &&
            pickerController!.config.selectType == .any &&
            isMultipleSelect {
            videoLoadSingleCell = true
        }
        config = pickerController!.config.photoList
        updateTitle()
    }
    func configColor() {
        let isDark = PhotoManager.isDark
        view.backgroundColor = isDark ? config.backgroundDarkColor : config.backgroundColor
        collectionView.backgroundColor = isDark ? config.backgroundDarkColor : config.backgroundColor
        let titleColor = isDark ? pickerController?.config.navigationTitleDarkColor : pickerController?.config.navigationTitleColor
        if pickerController!.config.albumShowMode == .popup {
            titleView.titleColor = titleColor
        }else {
            titleLabel.textColor = titleColor
        }
    }
    func updateTitle() {
        if pickerController!.config.albumShowMode == .popup {
            titleView.title = assetCollection?.albumName
        }else {
            titleLabel.text = assetCollection?.albumName
        }
    }
    
    func setupEmptyView() {
        if assets.isEmpty {
            collectionView.addSubview(emptyView)
        }else {
            emptyView.removeFromSuperview()
        }
    }
    func scrollToCenter(for photoAsset: PhotoAsset?) {
        if assets.isEmpty {
            return
        }
        if let photoAsset = photoAsset, var item = assets.firstIndex(of: photoAsset) {
            if needOffset {
                item += 1
            }
            collectionView.scrollToItem(at: IndexPath(item: item, section: 0), at: .centeredVertically, animated: false)
        }
    }
    func scrollCellToVisibleArea(_ cell: PhotoPickerBaseViewCell) {
        if assets.isEmpty {
            return
        }
        let rect = cell.imageView.convert(cell.imageView.bounds, to: view)
        if rect.minY - collectionView.contentInset.top < 0 {
            if let indexPath = collectionView.indexPath(for: cell) {
                collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
            }
        }else if rect.maxY > view.height - collectionView.contentInset.bottom {
            if let indexPath = collectionView.indexPath(for: cell) {
                collectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
            }
        }
    }
    func scrollToAppropriatePlace(photoAsset: PhotoAsset?) {
        if assets.isEmpty {
            return
        }
        var item = !pickerController!.config.reverseOrder ? assets.count - 1 : 0
        if let photoAsset = photoAsset {
            item = assets.firstIndex(of: photoAsset) ?? item
            if needOffset {
                item += 1
            }
        }
        collectionView.scrollToItem(at: IndexPath(item: item, section: 0), at: .centeredVertically, animated: false)
    }
    func getCell(for item: Int) -> PhotoPickerBaseViewCell? {
        if assets.isEmpty {
            return nil
        }
        let cell = collectionView.cellForItem(at: IndexPath.init(item: item, section: 0)) as? PhotoPickerBaseViewCell
        return cell
    }
    func getCell(for photoAsset: PhotoAsset) -> PhotoPickerBaseViewCell? {
        if let item = getIndexPath(for: photoAsset)?.item {
            return getCell(for: item)
        }
        return nil
    }
    func getIndexPath(for photoAsset: PhotoAsset) -> IndexPath? {
        if assets.isEmpty {
            return nil
        }
        if var item = assets.firstIndex(of: photoAsset) {
            if needOffset {
                item += 1
            }
            return IndexPath(item: item, section: 0)
        }
        return nil
    }
    func reloadCell(for photoAsset: PhotoAsset) {
        if let indexPath = getIndexPath(for: photoAsset) {
            collectionView.reloadItems(at: [indexPath])
        }
    }
    func getPhotoAsset(for index: Int) -> PhotoAsset {
        var photoAsset: PhotoAsset
        if needOffset {
            photoAsset = assets[index - 1]
        }else {
            photoAsset = assets[index]
        }
        return photoAsset
    }
    func addedPhotoAsset(for photoAsset: PhotoAsset) {
        let indexPath: IndexPath
        if pickerController!.config.reverseOrder {
            assets.insert(photoAsset, at: 0)
            indexPath = IndexPath(item: needOffset ? 1 : 0, section: 0)
        }else {
            assets.append(photoAsset)
            indexPath = IndexPath(item: needOffset ? assets.count : assets.count - 1, section: 0)
        }
        collectionView.insertItems(at: [indexPath])
        collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
    }
    func changedAssetCollection(collection: PhotoAssetCollection?) {
        _ = ProgressHUD.showLoadingHUD(addedTo: navigationController?.view, animated: true)
        if collection == nil {
            updateTitle()
            fetchPhotoAssets()
            reloadAlbumData()
            return
        }
        if pickerController!.config.albumShowMode == .popup {
            assetCollection.isSelected = false
            collection?.isSelected = true
        }
        assetCollection = collection
        updateTitle()
        fetchPhotoAssets()
        reloadAlbumData()
    }
    func reloadAlbumData() {
        if pickerController!.config.albumShowMode == .popup {
            albumView.tableView.reloadData()
            albumView.updatePrompt()
        }
    }
    
    func updateBottomPromptView() {
        if isMultipleSelect {
            bottomView.updatePromptView()
        }
    }
    
    
    func updateCellSelectedTitle() {
        for visibleCell in collectionView.visibleCells {
            if visibleCell is PhotoPickerBaseViewCell, let photoAsset = (visibleCell as? PhotoPickerBaseViewCell)?.photoAsset, let pickerController = pickerController {
                let cell = visibleCell as! PhotoPickerBaseViewCell
                if !photoAsset.isSelected && config.cell.showDisableMask {
                    cell.canSelect = pickerController.canSelectAsset(for: photoAsset, showHUD: false)
                }
                cell.updateSelectedState(isSelected: photoAsset.isSelected, animated: false)
            }
        }
    }
}
// MARK: Action
extension PhotoPickerViewController {
    
     
    @objc func didTitleViewClick(control: AlbumTitleView) {
        control.isSelected = !control.isSelected
        if control.isSelected {
            // 展开
            if albumView.assetCollectionsArray.isEmpty {
//                ProgressHUD.showLoadingHUD(addedTo: view, animated: true)
//                ProgressHUD.hideHUD(forView: weakSelf?.navigationController?.view, animated: true)
                control.isSelected = false
                return
            }
            openAlbumView()
        }else {
            // 收起
            closeAlbumView()
        }
    }
    
    @objc func didAlbumBackgroudViewClick() {
        titleView.isSelected = false
        closeAlbumView()
    }
    
    func openAlbumView() {
        albumBackgroudView.alpha = 0
        albumBackgroudView.isHidden = false
        albumView.scrollToMiddle()
        UIView.animate(withDuration: 0.25) {
            self.albumBackgroudView.alpha = 1
            self.configAlbumViewFrame()
            self.titleView.arrowView.transform = CGAffineTransform.init(rotationAngle: .pi)
        }
    }
    
    func closeAlbumView() {
        UIView.animate(withDuration: 0.25) {
            self.albumBackgroudView.alpha = 0
            self.configAlbumViewFrame()
            self.titleView.arrowView.transform = CGAffineTransform.init(rotationAngle: 2 * .pi)
        } completion: { (isFinish) in
            if isFinish {
                self.albumBackgroudView.isHidden = true
            }
        }
    }
    
    func configAlbumViewFrame() {
        self.albumView.size = CGSize(width: view.width, height: getAlbumViewHeight())
        if titleView.isSelected {
            if self.navigationController?.modalPresentationStyle == UIModalPresentationStyle.fullScreen && UIDevice.isPortrait {
                self.albumView.y = UIDevice.navigationBarHeight
            }else {
                self.albumView.y = self.navigationController?.navigationBar.height ?? 0
            }
        }else {
            self.albumView.y = -self.albumView.height
        }
    }
    
    func getAlbumViewHeight() -> CGFloat {
        var albumViewHeight = CGFloat(albumView.assetCollectionsArray.count) * albumView.config.cellHeight
        if AssetManager.authorizationStatusIsLimited() &&
            pickerController!.config.allowLoadPhotoLibrary {
            albumViewHeight += 40
        }
        if albumViewHeight > view.height * 0.75 {
            albumViewHeight = view.height * 0.75
        }
        return albumViewHeight
    }
    
    @objc func didCancelItemClick() {
        pickerController?.cancelCallback()
    }
}

// MARK: UICollectionViewDataSource
extension PhotoPickerViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return config.allowAddCamera && canAddCamera && pickerController != nil ? assets.count + 1 : assets.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if config.allowAddCamera && canAddCamera && pickerController != nil {
            if !pickerController!.config.reverseOrder {
                if indexPath.item == assets.count {
                    return self.cameraCell
                }
            }else {
                if indexPath.item == 0 {
                    return self.cameraCell
                }
            }
        }
        let cell: PhotoPickerBaseViewCell
        let photoAsset = getPhotoAsset(for: indexPath.item)
        if pickerController?.config.selectMode == .single || (photoAsset.mediaType == .video && videoLoadSingleCell) {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PhotoPickerViewCell.classForCoder()), for: indexPath) as! PhotoPickerBaseViewCell
        }else {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(PhotoPickerSelectableViewCell.classForCoder()), for: indexPath) as! PhotoPickerBaseViewCell
        }
        cell.delegate = self
        cell.config = config.cell
        cell.photoAsset = photoAsset
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension PhotoPickerViewController: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let pickerController = pickerController, cell is PhotoPickerBaseViewCell {
            let myCell: PhotoPickerBaseViewCell = cell as! PhotoPickerBaseViewCell
            let photoAsset = getPhotoAsset(for: indexPath.item)
            if !photoAsset.isSelected && config.cell.showDisableMask {
                myCell.canSelect = pickerController.canSelectAsset(for: photoAsset, showHUD: false)
            }else {
                myCell.canSelect = true
            }
        }
    }
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let myCell: PhotoPickerBaseViewCell? = cell as? PhotoPickerBaseViewCell
        myCell?.cancelRequest()
    }
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if navigationController?.topViewController != self {
            return
        }
        collectionView.deselectItem(at: indexPath, animated: false)
        let cell = collectionView.cellForItem(at: indexPath)
        if cell == nil {
            return
        }
        if cell is PickerCamerViewCell {
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                ProgressHUD.showWarningHUD(addedTo: self.navigationController?.view, text: "相机不可用!".localized, animated: true, delay: 1.5)
                return
            }
            AssetManager.requestCameraAccess { (granted) in
                if granted {
                    self.presentCameraViewController()
                }else {
                    PhotoTools.showNotCameraAuthorizedAlert(viewController: self)
                }
            }
        }else if cell is PhotoPickerBaseViewCell {
            let myCell = cell as! PhotoPickerBaseViewCell
            if !myCell.canSelect {
                return
            }
            if let pickerController = pickerController {
                if !pickerController.shouldClickCell(photoAsset: myCell.photoAsset, index: indexPath.item) {
                    return
                }
            }
            pushPreviewViewController(previewAssets: assets, currentPreviewIndex: needOffset ? indexPath.item - 1 : indexPath.item)
        }
    }
}

// MARK: UIImagePickerControllerDelegate
extension PhotoPickerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func presentCameraViewController() {
        if let pickerController = pickerController {
            if !pickerController.shouldPresentCamera() {
                return
            }
        }
        let imagePickerController = CameraViewController.init()
        imagePickerController.sourceType = .camera
        imagePickerController.delegate = self
        imagePickerController.videoMaximumDuration = config.camera.videoMaximumDuration
        imagePickerController.videoQuality = config.camera.videoQuality
        imagePickerController.allowsEditing = config.camera.allowsEditing
        imagePickerController.cameraDevice = config.camera.cameraDevice
        var mediaTypes: [String]
        if !config.camera.mediaTypes.isEmpty {
            mediaTypes = config.camera.mediaTypes
        }else {
            switch pickerController!.config.selectType {
            case .photo:
                mediaTypes = [kUTTypeImage as String]
                break
            case .video:
                mediaTypes = [kUTTypeMovie as String]
                break
            default:
                mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
            }
        }
        imagePickerController.mediaTypes = mediaTypes
        present(imagePickerController, animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        _ = ProgressHUD.showLoadingHUD(addedTo: self.navigationController?.view, animated: true)
        picker.dismiss(animated: true, completion: nil)
        DispatchQueue.global().async {
            let mediaType = info[.mediaType] as! String
            var photoAsset: PhotoAsset
            if mediaType == kUTTypeImage as String {
                var image: UIImage? = (info[.editedImage] ?? info[.originalImage]) as? UIImage
                image = image?.scaleSuitableSize()
                if let image = image, self.config.saveSystemAlbum {
                    self.saveSystemAlbum(for: image, mediaType: .image)
                    return
                }
                photoAsset = PhotoAsset.init(image: image, localIdentifier: String(Date.init().timeIntervalSince1970))
            }else {
                let startTime = info[UIImagePickerController.InfoKey.init(rawValue: "_UIImagePickerControllerVideoEditingStart")] as? TimeInterval
                let endTime = info[UIImagePickerController.InfoKey.init(rawValue: "_UIImagePickerControllerVideoEditingEnd")] as? TimeInterval
                let videoURL: URL? = info[.mediaURL] as? URL
                if startTime != nil && endTime != nil && videoURL != nil {
                    let avAsset = AVAsset.init(url: videoURL!)
                    PhotoTools.exportEditVideo(for: avAsset, startTime: startTime!, endTime: endTime!, presentName: self.config.camera.videoEditExportQuality) { (url, error) in
                        if let url = url, error == nil {
                            if self.config.saveSystemAlbum {
                                self.saveSystemAlbum(for: url, mediaType: .video)
                                return
                            }
                            let phAsset: PhotoAsset = PhotoAsset.init(videoURL: url, localIdentifier: String(Date.init().timeIntervalSince1970))
                            self.addedCameraPhotoAsset(phAsset)
                        }else {
                            ProgressHUD.hideHUD(forView: self.navigationController?.view, animated: false)
                            ProgressHUD.showWarningHUD(addedTo: self.navigationController?.view, text: "视频导出失败".localized, animated: true, delay: 1.5)
                        }
                    }
                    return
                }else {
                    if let videoURL = videoURL, self.config.saveSystemAlbum {
                        self.saveSystemAlbum(for: videoURL, mediaType: .video)
                        return
                    }
                    photoAsset = PhotoAsset.init(videoURL: videoURL, localIdentifier: String(Date.init().timeIntervalSince1970))
                }
            }
            self.addedCameraPhotoAsset(photoAsset)
        }
    }
    func saveSystemAlbum(for asset: Any, mediaType: PHAssetMediaType) {
        AssetManager.saveSystemAlbum(forAsset: asset, mediaType: mediaType, customAlbumName: config.customAlbumName, creationDate: nil, location: nil) { (phAsset) in
            if let phAsset = phAsset {
                self.addedCameraPhotoAsset(PhotoAsset.init(asset: phAsset))
            }else {
                DispatchQueue.main.async {
                    ProgressHUD.hideHUD(forView: self.navigationController?.view, animated: true)
                    ProgressHUD.showWarningHUD(addedTo: self.navigationController?.view, text: "保存失败".localized, animated: true, delay: 1.5)
                }
            }
        }
    }
    func addedCameraPhotoAsset(_ photoAsset: PhotoAsset) {
        func addPhotoAsset(_ photoAsset: PhotoAsset) {
            ProgressHUD.hideHUD(forView: self.navigationController?.view, animated: true)
            if self.config.takePictureCompletionToSelected {
                if self.pickerController!.addedPhotoAsset(photoAsset: photoAsset) {
                    self.updateCellSelectedTitle()
                }
            }
            self.pickerController?.updateAlbums(coverImage: photoAsset.originalImage, count: 1)
            if photoAsset.mediaSubType == .localImage || photoAsset.mediaSubType == .localVideo {
                self.pickerController?.addedLocalCameraAsset(photoAsset: photoAsset)
            }
            if self.pickerController!.config.albumShowMode == .popup {
                self.albumView.tableView.reloadData()
            }
            self.addedPhotoAsset(for: photoAsset)
            self.bottomView.updateFinishButtonTitle()
            self.setupEmptyView()
        }
        if Thread.current.isMainThread {
            addPhotoAsset(photoAsset)
        }else {
            DispatchQueue.main.async {
                addPhotoAsset(photoAsset)
            }
        }
    }
}

// MARK: PhotoPreviewViewControllerDelegate
extension PhotoPickerViewController: PhotoPreviewViewControllerDelegate  {
    
    func pushPreviewViewController(previewAssets: [PhotoAsset], currentPreviewIndex: Int) {
        let vc = PhotoPreviewViewController.init()
        vc.previewAssets = previewAssets
        vc.currentPreviewIndex = currentPreviewIndex
        vc.delegate = self
        navigationController?.delegate = vc
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func previewViewController(_ previewController: PhotoPreviewViewController, didOriginalButton isOriginal: Bool) {
        if isMultipleSelect {
            bottomView.boxControl.isSelected = isOriginal
            bottomView.requestAssetBytes()
        }
    }
    func previewViewController(_ previewController: PhotoPreviewViewController, didSelectBox photoAsset: PhotoAsset, isSelected: Bool) {
        updateCellSelectedTitle()
        bottomView.updateFinishButtonTitle()
    }
}

// MARK: AlbumViewDelegate
extension PhotoPickerViewController: AlbumViewDelegate {
    
    func albumView(_ albumView: AlbumView, didSelectRowAt assetCollection: PhotoAssetCollection) {
        didAlbumBackgroudViewClick()
        if self.assetCollection == assetCollection {
            return
        }
        titleView.title = assetCollection.albumName
        assetCollection.isSelected = true
        self.assetCollection.isSelected = false
        self.assetCollection = assetCollection
        _ = ProgressHUD.showLoadingHUD(addedTo: navigationController?.view, animated: true)
        fetchPhotoAssets()
    }
}

// MARK: PhotoPickerBottomViewDelegate
extension PhotoPickerViewController: PhotoPickerBottomViewDelegate {
    
    func bottomView(didPreviewButtonClick bottomView: PhotoPickerBottomView) {
        pushPreviewViewController(previewAssets: pickerController!.selectedAssetArray, currentPreviewIndex: 0)
    }
    func bottomView(didFinishButtonClick bottomView: PhotoPickerBottomView) {
        pickerController?.finishCallback()
    }
    func bottomView(_ bottomView: PhotoPickerBottomView, didOriginalButtonClick isOriginal: Bool) {
        pickerController?.originalButtonCallback()
    }
}

// MARK: PhotoPickerViewCellDelegate
extension PhotoPickerViewController: PhotoPickerViewCellDelegate {
    
    public func cell(_ cell: PhotoPickerBaseViewCell, didSelectControl isSelected: Bool) {
        if isSelected {
            // 取消选中
            _ = pickerController?.removePhotoAsset(photoAsset: cell.photoAsset)
            cell.updateSelectedState(isSelected: false, animated: true)
            updateCellSelectedTitle()
        }else {
            // 选中
            if pickerController!.addedPhotoAsset(photoAsset: cell.photoAsset) {
                cell.updateSelectedState(isSelected: true, animated: true)
                updateCellSelectedTitle()
            }
        }
        bottomView.updateFinishButtonTitle()
    }
}
