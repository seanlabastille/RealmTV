//
//  TalkViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 11/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import AVKit

protocol TalkViewControllerDelegate {
    func talkCurrentTimeChanged(_ talkViewController: TalkViewController, currentTime: TimeInterval)
}

class TalkViewController : AVPlayerViewController {
    var slideOverlayView: UIImageView?
    var slidesTimer: DispatchSourceTimer?
    var talk: Talk?
    var talkDelegate: TalkViewControllerDelegate?
    
    init(feedItem: FeedItem) {
        super.init(nibName: nil, bundle: nil)
        if let talk = feedItem.talk {
            self.talk = talk
            player = AVPlayer(playerItem: AVPlayerItem(asset: AVAsset(url: talk.videoURL)))
            // Fetch first slide
            DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosUserInitiated).async {
                if let slide = talk[slide: 0] {
                    self.slideOverlayView = UIImageView(image: slide)
                    DispatchQueue.main.async {
                        guard let slideOverlayView = self.slideOverlayView else { return }
                        let bounds = self.view.bounds
                        var slideSize = bounds.size
                        slideSize /= 3
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
            // Keep an eye on current play time and fetch relevant slides
            slidesTimer = DispatchSource.timer(flags: [], queue: DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosUserInitiated))
            if let timer = slidesTimer {
                timer.setEventHandler {
                    if self.player?.rate > 0 {
                        let second = TimeInterval((self.player?.currentTime().value)!/1_000_000_000)
                        self.talkDelegate?.talkCurrentTimeChanged(self, currentTime: second)
                        if let slideNumber = self.talk?.slideTimes[second+1] { // Look ahead a second to have the slide fetched in time
                            dump("\(second)s \(slideNumber-1)")
                            // Prefetch next 10 slides
                            DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosUtility).async {
                                (max(0,slideNumber-1)..<(slideNumber+10)).forEach { _ = talk[slide: $0] }
                            }
                            if let slide = talk[slide: max(0,slideNumber-1)] {
                                DispatchQueue.main.async {
                                    self.slideOverlayView?.image = slide
                                }
                            }
                        }
                    }
                }
                timer.scheduleOneshot(deadline: DispatchTime.now())
                timer.resume()
            }
            player?.play()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
