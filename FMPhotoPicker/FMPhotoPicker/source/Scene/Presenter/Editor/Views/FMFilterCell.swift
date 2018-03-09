//
//  FMFilterCell.swift
//  FMPhotoPicker
//
//  Created by c-nguyen on 2018/02/27.
//  Copyright © 2018 Tribal Media House. All rights reserved.
//

import UIKit

class FMFilterCell: UICollectionViewCell {
    static let reussId = String(describing: self)
    public var imageView: UIImageView
    public var name: UILabel
    
    let selectedColor = UIColor(red: 1, green: 81/255, blue: 81/255, alpha: 1)
    let unselectColor = UIColor(red: 114/255, green: 114/255, blue: 114/255, alpha: 1)
    
    override init(frame: CGRect) {
        imageView = UIImageView()
        name = UILabel()
        
        super.init(frame: frame)
        
        imageView.frame = CGRect(x: 15, y: 8, width: 60, height: 60)
        imageView.layer.cornerRadius = imageView.frame.width / 2
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        imageView.layer.borderWidth = 0
        imageView.layer.borderColor = selectedColor.cgColor
        
        self.addSubview(imageView)
        self.addSubview(name)
        
        name.translatesAutoresizingMaskIntoConstraints = false
        name.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        name.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
        
        name.text = "Filter"
        name.textColor = unselectColor
        name.font = UIFont.systemFont(ofSize: 12)
    }
    
    override func prepareForReuse() {
        setDeselected()
    }
    
    public func setSelected() {
        imageView.layer.borderWidth = 2
        name.textColor = selectedColor
    }
    
    public func setDeselected() {
        imageView.layer.borderWidth = 0
        name.textColor = unselectColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
