//
//  TalkViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 11/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import AVKit

class TalkViewController : AVPlayerViewController {
    var slideOverlayView: UIImageView?
    var slidesTimer: dispatch_source_t?
    var talk: Talk?
    
    init(feedItem: FeedItem) {
        super.init(nibName: nil, bundle: nil)
        if let talk = feedItem.talk {
            self.talk = talk
            player = AVPlayer(playerItem: AVPlayerItem(asset: AVAsset(URL: talk.videoURL)))
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                if let slide = talk[slide: 0] {
                    self.slideOverlayView = UIImageView(image: slide)
                    self.contentOverlayView?.addSubview(self.slideOverlayView!)
                }
            }
            slidesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0))
            if let timer = slidesTimer {
                dispatch_source_set_event_handler(timer) {
                    
                    let second = NSTimeInterval((self.player?.currentTime().value)!/1_000_000_000)
                    if let slideNumber = self.talk?.slideTimes[second] {
                        dump("\(second)s \(slideNumber)")
                        if let slide = talk[slide: slideNumber] {
                            self.slideOverlayView?.image = slide
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
