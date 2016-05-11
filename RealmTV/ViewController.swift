//
//  ViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 10/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit
import AVKit 

class ViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var attributedTextView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let data = NSData(contentsOfURL: NSURL(string:"https://developer.apple.com/xcode/download/")!)!
        if let attributedString = try? NSAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType], documentAttributes: nil),
            textView = textView {
            textView.attributedText = attributedString
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        dump("\(#function)")
        if let talkVC = segue.destinationViewController as? TalkViewController {
            talkVC.player = AVPlayer(playerItem: AVPlayerItem(asset:AVAsset(URL: NSURL(string: "https://embed-ssl.wistia.com/deliveries/e188517bd2a7f96f0dc5ea8e80b6458ff9f5dc5d.bin")!)))
            
            talkVC.contentOverlayView
        }
    }

}

