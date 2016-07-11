//
//  TalkDetailViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 03/07/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit

class TalkDetailViewController: UIViewController {
    @IBOutlet weak var talksPosterImageView: UIImageView!
//    @IBOutlet weak var talksTitleLabel: UILabel!
    @IBOutlet weak var talkDescriptionLabel: UILabel!
    
    var feedItem: FeedItem? {
        didSet {
            title = feedItem?.title
            talkDescriptionLabel.text = feedItem?.description
            DispatchQueue.global(attributes: [DispatchQueue.GlobalAttributes.qosUserInitiated]).async {
                if let slide = self.feedItem?.talk?[slide: 0] {
                    DispatchQueue.main.async {
                        self.talksPosterImageView.image = slide
                    }
                }
            }
        }
    }
}
