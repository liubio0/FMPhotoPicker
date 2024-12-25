//
//  FMPhotoPickerViewController.swift
//  FMPhotoPicker
//
//  Created by c-nguyen on 2018/01/23.
//  Copyright © 2018 Tribal Media House. All rights reserved.
//

import UIKit
import Photos

// MARK: - Delegate protocol
public protocol FMPhotoPickerViewControllerDelegate: class {
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishPickingPhotoWith photos: [UIImage])
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishSelectingPhotoWith photo: UIImage)
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishPickingPhotoWith photos: [UIImage], fileNames: [String?])
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishSelectingPhotoWith photo: UIImage, fileName: String?)
    func fmAllPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishPickingPhotoWith photos: [UIImage], fileNames: [String?], fileDirectorys: [String?], fileCreationDates: [String?])
}

public extension FMPhotoPickerViewControllerDelegate {
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishPickingPhotoWith photos: [UIImage], fileNames: [String?]) {}
    func fmPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishSelectingPhotoWith photo: UIImage, fileName: String?) {}
    func fmAllPhotoPickerController(_ picker: FMPhotoPickerViewController, didFinishPickingPhotoWith photos: [UIImage], fileNames: [String?], fileDirectorys: [String?], fileCreationDates: [String?]) {}
}

public protocol FMPhotoPickerSheetDelegate: class {
    func showSheet(titles:[String], callback: @escaping (_ results: Int) -> Void)
}

public class FMPhotoPickerViewController: UIViewController {
    // MARK: - Outlet
    @IBOutlet weak var imageCollectionView: UICollectionView!
    @IBOutlet weak var numberOfSelectedPhotoContainer: UIView!
    @IBOutlet weak var numberOfSelectedPhoto: UILabel!
    @IBOutlet weak var determineButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private lazy var selectAlbumButton: UIButton = {
        let temp = UIButton()
        temp.addTarget(self, action: #selector(openSelectAlbumActionSheet), for: .touchUpInside)
        return temp
    }()
    
    // MARK: - Public
    public weak var delegate: FMPhotoPickerViewControllerDelegate? = nil
    public weak var sheetDelegate: FMPhotoPickerSheetDelegate?
    // MARK: - Private
    
    // Index of photo that is currently displayed in PhotoPresenterViewController.
    // Track this to calculate the destination frame for dismissal animation
    // from PhotoPresenterViewController to this ViewController
    private var presentedPhotoIndex: Int?

    private let config: FMPhotoPickerConfig
    
    // The controller for multiple select/deselect
    private lazy var batchSelector: FMPhotoPickerBatchSelector = {
        return FMPhotoPickerBatchSelector(viewController: self, collectionView: self.imageCollectionView, dataSource: self.dataSource)
    }()
    
    private var dataSource: FMPhotosDataSource! {
        didSet {
            if self.config.selectMode == .multiple && self.config.allowBatchSelect {
                // Enable batchSelector in multiple selection mode only
                self.batchSelector.enable()
            }
        }
    }
    
    // MARK: - Init
    public init(config: FMPhotoPickerConfig) {
        self.config = config
        super.init(nibName: "FMPhotoPickerViewController", bundle: Bundle(for: type(of: self)))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Life cycle
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.dataSource == nil {
            self.requestAndFetchAssets()
        }
    }
    
    // MARK: - Setup View
    private func setupView() {
        let reuseCellNib = UINib(nibName: "FMPhotoPickerImageCollectionViewCell", bundle: Bundle(for: self.classForCoder))
        self.imageCollectionView.register(reuseCellNib, forCellWithReuseIdentifier: FMPhotoPickerImageCollectionViewCell.reuseId)
        self.imageCollectionView.dataSource = self
        self.imageCollectionView.delegate = self
        
        self.numberOfSelectedPhotoContainer.layer.cornerRadius = self.numberOfSelectedPhotoContainer.frame.size.width / 2
        self.numberOfSelectedPhotoContainer.isHidden = true
        self.determineButton.isHidden = true
        self.selectAlbumButton.isHidden = true

        
        // set button title
        self.cancelButton.setTitle(config.strings["picker_button_cancel"], for: .normal)
        self.cancelButton.titleLabel!.font = UIFont.systemFont(ofSize: config.titleFontSize)
        self.determineButton.setTitle(config.strings["picker_button_select_done"], for: .normal)
        self.determineButton.titleLabel!.font = UIFont.systemFont(ofSize: config.titleFontSize)
        self.selectAlbumButton.titleLabel!.font = UIFont.systemFont(ofSize: config.titleFontSize)
        self.selectAlbumButton.setTitleColor(UIColor.black, for: .normal)
        self.selectAlbumButton.addTarget(self, action: #selector(openSelectAlbumActionSheet), for: .touchUpInside)
        self.view.addSubview(selectAlbumButton)
        selectAlbumButton.frame = CGRect(x: 400 / 2 - 60, y: 20, width: 120, height: 36)

    }
    
    // MARK: - Target Actions
    @IBAction func onTapCancel(_ sender: Any) {
        self.dismiss(animated: true)
    }
    
    @IBAction func onTapDetermine(_ sender: Any) {
        processDetermination()
    }
    
    // MARK: - Logic
    private func requestAndFetchAssets() {
        if Helper.canAccessPhotoLib() {
            self.fetchPhotos()
        } else {
            Helper.showDialog(in: self, ok: {
                Helper.requestAuthorizationForPhotoAccess(authorized: self.fetchPhotos, rejected: Helper.openIphoneSetting)
            })
        }
    }
    
    private func fetchPhotosWithAlbum(photoAssets: [PHAsset]) {
            let photoNoCloudAssets = photoAssets.filter { (model) -> Bool in
                return model.sourceType != PHAssetSourceType.typeCloudShared
            }
            let forceCropType = config.forceCropEnabled ? config.availableCrops.first! : nil
            let fmPhotoAssets = photoNoCloudAssets.map { FMPhotoAsset(asset: $0, forceCropType: forceCropType) }
            self.dataSource = FMPhotosDataSource(photoAssets: fmPhotoAssets, photoAlbums: self.dataSource.photoAlbums)
            
            if self.dataSource.numberOfPhotos > 0 {
                self.imageCollectionView.reloadData()
                self.imageCollectionView.selectItem(at: IndexPath(row: self.dataSource.numberOfPhotos - 1, section: 0),
                                                    animated: false,
                                                    scrollPosition: .bottom)
            }
        }


    
    private func fetchPhotos() {
        //旧接口Helper.getAssets获取全部图片
        //新接口getAssetsAndAlbum除了获取全部图片外，根据用户相册返回分相册的图片，用户用户筛选自定义的相册图片。2022.08
        let result = Helper.getAssetsAndAlbum(allowMediaTypes: self.config.mediaTypes)
        let photoAssets = result.photoAssets
        let photoAlbums = result.photoAlbums //相册（除所有照片外）
        
        let photoNoCloudAssets = photoAssets.filter { (model) -> Bool in
            return model.sourceType != PHAssetSourceType.typeCloudShared
        }
        let forceCropType = config.forceCropEnabled ? config.availableCrops.first! : nil
        let fmPhotoAssets = photoNoCloudAssets.map { FMPhotoAsset(asset: $0, forceCropType: forceCropType) }
        self.dataSource = FMPhotosDataSource(photoAssets: fmPhotoAssets, photoAlbums: photoAlbums)
        if self.dataSource.photoAlbums.count > 0 {
            self.selectAlbumButton.isHidden = false
            self.selectAlbumButton.setTitle("所有照片∨", for: .normal)
        }
        
        if self.dataSource.numberOfPhotos > 0 {
            self.imageCollectionView.reloadData()
            self.imageCollectionView.selectItem(at: IndexPath(row: self.dataSource.numberOfPhotos - 1, section: 0),
                                                animated: false,
                                                scrollPosition: .bottom)
        }
    }
    
    public func updateControlBar() {
        if self.dataSource.numberOfSelectedPhoto() > 0 {
            self.determineButton.isHidden = false
            if self.config.selectMode == .multiple {
                self.numberOfSelectedPhotoContainer.isHidden = false
                self.numberOfSelectedPhoto.text = "\(self.dataSource.numberOfSelectedPhoto())"
            }
        } else {
            self.determineButton.isHidden = true
            self.numberOfSelectedPhotoContainer.isHidden = true
        }
    }
    
    private func processDetermination() {
        FMLoadingView.shared.show()
        
        var dict = [Int:UIImage]()
        var fileNameDict = [Int:String]()
        var fileDirectoryDict = [Int:String]()
        var fileCreationDateDict = [Int:String]()
        DispatchQueue.global(qos: .userInitiated).async {
            let multiTask = DispatchGroup()
            for (index, element) in self.dataSource.getSelectedPhotos().enumerated() {
                multiTask.enter()
                element.requestFullSizePhoto(cropState: .edited, filterState: .edited) {
                    if let image = $0 {
                        dict[index] = image
                    }
                    if let fileName = element.fileName {
                        fileNameDict[index] = fileName
                    }
                    if let fileDirectory = element.asset?.value(forKey: "directory") as? String {
                        fileDirectoryDict[index] = fileDirectory
                    }
                    if let fileCreationDate = element.asset?.creationDate {
                        let dateFormatter=DateFormatter()
                        dateFormatter.dateFormat="yyyyMMddHHmmss"
                        let dateStr = dateFormatter.string(from: fileCreationDate)
                        fileCreationDateDict[index] = dateStr
                    }
                    
                    multiTask.leave()
                }
            }
            multiTask.wait()
            
            let result = dict.sorted(by: { $0.key < $1.key }).map { $0.value }
            let fileNames = fileNameDict.sorted(by: { $0.key < $1.key }).map { $0.value }
            let fileDirectorys = fileDirectoryDict.sorted(by: { $0.key < $1.key }).map { $0.value }
            let fileCreationDates = fileCreationDateDict.sorted(by: { $0.key < $1.key }).map { $0.value }
            DispatchQueue.main.async {
                FMLoadingView.shared.hide()
                self.delegate?.fmPhotoPickerController(self, didFinishPickingPhotoWith: result)
                self.delegate?.fmPhotoPickerController(self, didFinishPickingPhotoWith: result, fileNames: fileNames)
                self.delegate?.fmAllPhotoPickerController(self, didFinishPickingPhotoWith: result, fileNames: fileNames, fileDirectorys: fileDirectorys, fileCreationDates: fileCreationDates)
            }
        }
    }
    
    @objc func openSelectAlbumActionSheet() {
        if self.dataSource.photoAlbums.count <= 0 { return }
        var titleArray: [String] = []
        for i in 0 ..< self.dataSource.photoAlbums.count {
            titleArray.append("\(self.dataSource.photoAlbums[i].name ?? "")(\(self.dataSource.photoAlbums[i].count))")
        }
        self.sheetDelegate?.showSheet(titles: titleArray, callback: {[weak self] (index) in
            for i in 0 ..< self!.dataSource.photoAlbums.count {
                if index == i+1 {
                    print("选择了 \(self!.dataSource.photoAlbums[i].name ?? "")")
                    self?.numberOfSelectedPhotoContainer.isHidden = true
                    self?.selectAlbumButton.setTitle("\(self!.dataSource.photoAlbums[i].name ?? "")∨", for: .normal)
                    self?.fetchPhotosWithAlbum(photoAssets: self!.dataSource.photoAlbums[i].photoAssets)
                } else {
                    self?.fetchPhotos()
//                    if let asset = self!.dataSource.photoAssets[0].asset {
//                        self?.selectAlbumButton.setTitle("所有照片∨", for: .normal)
//                        self?.fetchPhotosWithAlbum(photoAssets: asset)
//                    }
                }
            }
        })
//        let actionSheet = LCActionSheet(title: nil, cancelButtonTitle: "取消", clicked: { [weak self](actionSheet, index) in
//            for i in 0 ..< self!.dataSource.photoAlbums.count {
//                if index == i+1 {
//                    print("选择了 \(self!.dataSource.photoAlbums[i].name ?? "")")
//                    self?.numberOfSelectedPhotoContainer.isHidden = true
//                    self?.selectAlbumButton.setTitle("\(self!.dataSource.photoAlbums[i].name ?? "")∨", for: .normal)
//                    self?.fetchPhotosWithAlbum(photoAssets: self!.dataSource.photoAlbums[i].photoAssets)
//                }
//            }
//        }, otherButtonTitleArray: titleArray)
//        actionSheet.show()
    }

}

// MARK: - UICollectionViewDataSource
extension FMPhotoPickerViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let total = self.dataSource?.numberOfPhotos {
            return total
        }
        return 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FMPhotoPickerImageCollectionViewCell.reuseId, for: indexPath) as? FMPhotoPickerImageCollectionViewCell,
            let photoAsset = self.dataSource.photo(atIndex: indexPath.item) else {
            return UICollectionViewCell()
        }
        
        cell.loadView(photoAsset: photoAsset,
                      selectMode: self.config.selectMode,
                      selectedIndex: self.dataSource.selectedIndexOfPhoto(atIndex: indexPath.item))
        cell.onTapSelect = { [unowned self, unowned cell] in
            if let selectedIndex = self.dataSource.selectedIndexOfPhoto(atIndex: indexPath.item) {
                self.dataSource.unsetSeclectedForPhoto(atIndex: indexPath.item)
                cell.performSelectionAnimation(selectedIndex: nil)
                self.reloadAffectedCellByChangingSelection(changedIndex: selectedIndex)
            } else {
                self.tryToAddPhotoToSelectedList(photoIndex: indexPath.item)
                self.selectPhotoHandle(at: indexPath.item)
            }
            self.updateControlBar()
        }
        
        return cell
    }
    
    private func selectPhotoHandle(at index: Int) {
        //选中照片
        let selectedPhoto = self.dataSource.photo(atIndex: index)
        selectedPhoto?.requestFullSizePhoto(cropState: .edited, filterState: .edited) {
            if let image = $0 {
                DispatchQueue.main.async {
                    self.delegate?.fmPhotoPickerController(self, didFinishSelectingPhotoWith: image)
                    self.delegate?.fmPhotoPickerController(self, didFinishSelectingPhotoWith: image, fileName: selectedPhoto?.fileName)
                }
            }
        }
    }
    
    /**
     Reload all photocells that behind the deselected photocell
     - parameters:
        - changedIndex: The index of the deselected photocell in the selected list
     */
    public func reloadAffectedCellByChangingSelection(changedIndex: Int) {
        let affectedList = self.dataSource.affectedSelectedIndexs(changedIndex: changedIndex)
        let indexPaths = affectedList.map { return IndexPath(row: $0, section: 0) }
        self.imageCollectionView.reloadItems(at: indexPaths)
    }
    
    /**
     Try to insert the photo at specify index to selectd list.
     In Single selection mode, it will remove all the previous selection and add new photo to the selected list.
     In Multiple selection mode, If the current number of select image/video does not exceed the maximum number specified in the Config,
     the photo will be added to selected list. Otherwise, a warning dialog will be displayed and NOTHING will be added.
     */
    public func tryToAddPhotoToSelectedList(photoIndex index: Int) {
        if self.config.selectMode == .multiple {
            guard let fmMediaType = self.dataSource.mediaTypeForPhoto(atIndex: index) else { return }

            var canBeAdded = true
            
            switch fmMediaType {
            case .image:
                if self.dataSource.countSelectedPhoto(byType: .image) >= self.config.maxImage {
                    canBeAdded = false
                    let warning = FMWarningView.shared
                    warning.message = String(format: config.strings["picker_warning_over_image_select_format"]!, self.config.maxImage)
                    warning.showAndAutoHide()
                }
            case .video:
                if self.dataSource.countSelectedPhoto(byType: .video) >= self.config.maxVideo {
                    canBeAdded = false
                    let warning = FMWarningView.shared
                    warning.message = String(format: config.strings["picker_warning_over_video_select_format"]!, self.config.maxVideo)
                    warning.showAndAutoHide()
                }
            case .unsupported:
                break
            }
            
            if canBeAdded {
                self.dataSource.setSeletedForPhoto(atIndex: index)
                self.imageCollectionView.reloadItems(at: [IndexPath(row: index, section: 0)])
                self.updateControlBar()
            }
        } else {  // single selection mode
            var indexPaths = [IndexPath]()
            self.dataSource.getSelectedPhotos().forEach { photo in
                guard let photoIndex = self.dataSource.index(ofPhoto: photo) else { return }
                indexPaths.append(IndexPath(row: photoIndex, section: 0))
                self.dataSource.unsetSeclectedForPhoto(atIndex: photoIndex)
            }
            
            self.dataSource.setSeletedForPhoto(atIndex: index)
            indexPaths.append(IndexPath(row: index, section: 0))
            self.imageCollectionView.reloadItems(at: indexPaths)
            self.updateControlBar()
        }
    }
}

// MARK: - UICollectionViewDelegate
extension FMPhotoPickerViewController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = FMPhotoPresenterViewController(config: self.config, dataSource: self.dataSource, initialPhotoIndex: indexPath.item)
        
        self.presentedPhotoIndex = indexPath.item
        
        vc.didSelectPhotoHandler = { photoIndex in
            self.tryToAddPhotoToSelectedList(photoIndex: photoIndex)
            self.selectPhotoHandle(at: photoIndex)
        }
        vc.didDeselectPhotoHandler = { photoIndex in
            if let selectedIndex = self.dataSource.selectedIndexOfPhoto(atIndex: photoIndex) {
                self.dataSource.unsetSeclectedForPhoto(atIndex: photoIndex)
                self.reloadAffectedCellByChangingSelection(changedIndex: selectedIndex)
                self.imageCollectionView.reloadItems(at: [IndexPath(row: photoIndex, section: 0)])
                self.updateControlBar()
            }
        }
        vc.didMoveToViewControllerHandler = { vc, photoIndex in
            self.presentedPhotoIndex = photoIndex
        }
        vc.didTapDetermine = {
            self.processDetermination()
        }
        
        vc.view.frame = self.view.frame
        vc.transitioningDelegate = self
        vc.modalPresentationStyle = .custom
        vc.modalPresentationCapturesStatusBarAppearance = true
        self.present(vc, animated: true)
    }
}

// MARK: - UIViewControllerTransitioningDelegate
extension FMPhotoPickerViewController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animationController = FMZoomInAnimationController()
        animationController.getOriginFrame = self.getOriginFrameForTransition
        return animationController
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let photoPresenterViewController = dismissed as? FMPhotoPresenterViewController else { return nil }
        let animationController = FMZoomOutAnimationController(interactionController: photoPresenterViewController.swipeInteractionController)
        animationController.getDestFrame = self.getOriginFrameForTransition
        return animationController
    }
    
    open func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard let animator = animator as? FMZoomOutAnimationController,
            let interactionController = animator.interactionController,
            interactionController.interactionInProgress
            else {
                return nil
        }
        
        interactionController.animator = animator
        return interactionController
    }
    
    func getOriginFrameForTransition() -> CGRect {
        guard let presentedPhotoIndex = self.presentedPhotoIndex,
            let cell = self.imageCollectionView.cellForItem(at: IndexPath(row: presentedPhotoIndex, section: 0))
            else {
                return CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.size.width, height: self.view.frame.size.width)
        }
        return cell.convert(cell.bounds, to: self.view)
    }
}
