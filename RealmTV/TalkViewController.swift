//
//  TalkViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 11/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import AVKit

protocol TalkViewControllerDelegate {
    func talkCurrentTimeChanged(talkViewController: TalkViewController, currentTime: NSTimeInterval)
}

class TalkViewController : AVPlayerViewController {
    var slideOverlayView: UIImageView?
    var slidesTimer: dispatch_source_t?
    var talk: Talk?
    var talkDelegate: TalkViewControllerDelegate?
    
    init(feedItem: FeedItem) {
        super.init(nibName: nil, bundle: nil)
        if let talk = feedItem.talk {
            self.talk = talk
            player = AVPlayer(playerItem: AVPlayerItem(asset: AVAsset(URL: talk.videoURL)))
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                if let slide = talk[slide: 0] {
                    self.slideOverlayView = UIImageView(image: slide)
                    dispatch_async(dispatch_get_main_queue()) {
                        guard let slideOverlayView = self.slideOverlayView else { return }
                        let bounds = self.view.bounds
                        let slideSize = CGSize(width: bounds.width/3, height: bounds.height/3)
                        slideOverlayView.frame =
                            CGRect(origin: CGPoint(
                                x: bounds.size.width-slideSize.width,
                                y: bounds.size.height-slideSize.height
                                ),
                                size: slideSize)
                        self.contentOverlayView?.addSubview(slideOverlayView)
                    }
                }
            }
            slidesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            if let timer = slidesTimer {
                dispatch_source_set_event_handler(timer) {
                    if self.player?.rate > 0 {
                        let second = NSTimeInterval((self.player?.currentTime().value)!/1_000_000_000)
                        self.talkDelegate?.talkCurrentTimeChanged(self, currentTime: second)
                        if let slideNumber = self.talk?.slideTimes[second+1] { // Look ahead a second to have the slide fetched in time
                            dump("\(second)s \(slideNumber-1)")
                            // Prefetch next 10 slides
                            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                                (max(0,slideNumber-1)..<(slideNumber+10)).forEach { talk[slide: $0] }
                            }
                            if let slide = talk[slide: max(0,slideNumber-1)] {
                                dispatch_async(dispatch_get_main_queue()) {
                                    self.slideOverlayView?.image = slide
                                }
                            }
                        }
                    }
                }
                dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC, 0)
                dispatch_resume(timer)
            }
            player?.play()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
