
//
//  ViewController.swift
//  realmtv
//
//  Created by Seán Labastille on 11/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit
import WebKit
import Alamofire
import AsyncNetwork
import Freddy

class ViewController: UIViewController, AsyncClientDelegate {
    var client: AsyncClient?
    var timer: dispatch_source_t?
    var seconds = 0
    
    @IBOutlet weak var talkTitleLabel: UILabel!
    var webView: WKWebView = {
        let source = try! String(contentsOfFile: NSBundle.mainBundle().pathForResource("transcriptWrangler", ofType: "js")!)
        let userScript = WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)
        
        let userContentController = WKUserContentController()
        userContentController.addUserScript(userScript)
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        
        return WKWebView(frame: CGRect(), configuration: configuration)
    }()
    @IBOutlet weak var webViewView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewView.addSubview(webView)
        
        webView.topAnchor.constraintEqualToAnchor(webViewView.topAnchor).active = true
        webView.bottomAnchor.constraintEqualToAnchor(webViewView.bottomAnchor).active = true
        webView.leadingAnchor.constraintEqualToAnchor(webViewView.leadingAnchor).active = true
        webView.trailingAnchor.constraintEqualToAnchor(webViewView.trailingAnchor).active = true
    }
    
    func client(theClient: AsyncClient!, didFindService service: NSNetService!, moreComing: Bool) -> Bool {
        print("\(theClient) \(service) \(moreComing)")
        return true
    }
    
    func client(theClient: AsyncClient!, didConnect connection: AsyncConnection!) {
        print("\(theClient) \(connection)")
    }
    
    func client(theClient: AsyncClient!, didDisconnect connection: AsyncConnection!) {
        print("\(#function) \(theClient) \(connection)")
        client = AsyncClient()
        client?.delegate = self
        client?.start()
    }
    
    func client(theClient: AsyncClient!, didReceiveCommand command: AsyncCommand, object: AnyObject!, connection: AsyncConnection!) {
        print("\(theClient) \(command) \(object) \(connection)")
        if let object = object as? [String: AnyObject],
           talkData = object["talk-begin"] as? NSData,
            item = try? FeedItem(json: JSON(data: talkData)) {
            dump(item)
            title = item.title
            webView.loadRequest(NSURLRequest(URL: item.url))
        }
        
        if let object = object as? [String: AnyObject],
            talkCurrentTime = object["talk-time"] as? NSTimeInterval {
            if transcriptShouldFollowSwitch.on { self.webView.evaluateJavaScript("scrollToTranscriptHeaderForTime(\(talkCurrentTime))", completionHandler: nil)
            }
            navigationItem.prompt = "\(talkCurrentTime)"
        }
    }
    
    @IBOutlet weak var slidePositionSegmentedControl: UISegmentedControl!
    @IBOutlet weak var slideSizeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var transcriptShouldFollowSwitch: UISwitch!
    
    @IBAction func slideControlValueChanged(sender: AnyObject) {
            client?.sendCommand(1, object: ["slide-position": slidePositionSegmentedControl.selectedSegmentIndex, "slide-size": slideSizeSegmentedControl.selectedSegmentIndex])
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        
        client = AsyncClient()
        client?.delegate = self
        client?.start()
    }
}

