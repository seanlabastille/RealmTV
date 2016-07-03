
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
    var timer: DispatchSource?
    var seconds = 0
    
    var webView: WKWebView = {
        let source = try! String(contentsOfFile: Bundle.main().pathForResource("transcriptWrangler", ofType: "js")!)
        let userScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
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
        
        webView.topAnchor.constraint(equalTo: webViewView.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: webViewView.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: webViewView.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: webViewView.trailingAnchor).isActive = true
        
        webView.loadHTMLString("<h1 style='font: -apple-system-headline;'>Talk transcript will be shown here</h1>", baseURL: nil)
        navigationItem.prompt = "Choose a talk on your TV to get started"
    }
    
    func client(_ theClient: AsyncClient!, didFind service: NetService!, moreComing: Bool) -> Bool {
        print("\(theClient) \(service) \(moreComing)")
        return true
    }
    
    func client(_ theClient: AsyncClient!, didConnect connection: AsyncConnection!) {
        print("\(theClient) \(connection)")
    }
    
    func client(_ theClient: AsyncClient!, didDisconnect connection: AsyncConnection!) {
        print("\(#function) \(theClient) \(connection)")
        client = AsyncClient()
        client?.delegate = self
        client?.start()
    }
    
    func client(_ theClient: AsyncClient!, didReceiveCommand command: AsyncCommand, object: AnyObject!, connection: AsyncConnection!) {
        print("\(theClient) \(command) \(object) \(connection)")
        if let object = object as? [String: AnyObject],
           talkData = object["talk-begin"] as? Data,
            item = try? FeedItem(json: JSON(data: talkData)) {
            navigationItem.prompt = nil
            title = item.title
            webView.load(URLRequest(url: item.url))
        }
        
        if let object = object as? [String: AnyObject],
            talkCurrentTime = object["talk-time"] as? TimeInterval {
            if transcriptShouldFollowSwitch.isOn { self.webView.evaluateJavaScript("scrollToTranscriptHeaderForTime(\(talkCurrentTime))", completionHandler: nil)
            }
            navigationItem.prompt = "\(talkCurrentTime)"
        }
    }
    
    @IBOutlet weak var slidePositionSegmentedControl: UISegmentedControl!
    @IBOutlet weak var slideSizeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var transcriptShouldFollowSwitch: UISwitch!
    
    @IBAction func slideControlValueChanged(_ sender: AnyObject) {
            client?.sendCommand(1, object: ["slide-position": slidePositionSegmentedControl.selectedSegmentIndex, "slide-size": slideSizeSegmentedControl.selectedSegmentIndex])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        client = AsyncClient()
        client?.delegate = self
        client?.start()
    }
}

