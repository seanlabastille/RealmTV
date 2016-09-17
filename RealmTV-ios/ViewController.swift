
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
import MultipeerConnectivity
import Freddy

class ViewController: UIViewController {
    var client: MCNearbyServiceBrowser?
    var session: MCSession?
    var timer: DispatchSource?
    var seconds = 0
    var transcriptShouldFollow = true
    var playbackControlsNavigationController: UIViewController?
    
    var webView: WKWebView = {
        let source = try! String(contentsOfFile: Bundle.main.path(forResource: "transcriptWrangler", ofType: "js")!)
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
        automaticallyAdjustsScrollViewInsets = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewView.addSubview(webView)
        
        webView.topAnchor.constraint(equalTo: webViewView.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: webViewView.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: webViewView.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: webViewView.trailingAnchor).isActive = true
        webView.loadHTMLString("<h1 style='font: -apple-system-headline; font-size: 32pt;'>Talk transcript will be shown here</h1>", baseURL: nil)
        navigationItem.prompt = "Choose a talk on your TV to get started"
    }

    func handleJSON(json data: Data) {
        if let freddyJSON = try? JSON(data: data), let feedItemJSON = freddyJSON["talk-begin"], let feedItem = try? FeedItem(json: feedItemJSON) {
            DispatchQueue.main.async {
                if feedItem.url != self.webView.url {
                    self.navigationItem.prompt = nil
                    self.title = feedItem.title
                    self.webView.load(URLRequest(url: feedItem.url))
                }
            }

        }
        if let freddyJSON = try? JSON(data: data), let talkCurrentTime = try? freddyJSON.getInt(at: "talk-time") {
            DispatchQueue.main.async {
                if self.transcriptShouldFollow { self.webView.evaluateJavaScript("scrollToTranscriptHeaderForTime(\(talkCurrentTime))", completionHandler: nil)
                }
                self.navigationItem.prompt = "\(talkCurrentTime)"
            }
        }
    }

    @IBAction func presentPlaybackControls(_ sender: AnyObject) {
        playbackControlsNavigationController = self.storyboard?.instantiateViewController(withIdentifier: "playbackControls")
        guard let playbackControlsNavigationController = playbackControlsNavigationController else { return }
        playbackControlsNavigationController.modalPresentationStyle = .custom
        playbackControlsNavigationController.transitioningDelegate = self
        if let playbackControlsViewController = playbackControlsNavigationController.childViewControllers.first as? PlaybackControlsViewController {
            playbackControlsViewController.delegate = self
        }
        present(playbackControlsNavigationController, animated: true, completion: nil)
    }
    
    @IBAction func unwindToTranscript(sender: UIStoryboardSegue) {
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)

        let peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID)
        session?.delegate = self

        client = MCNearbyServiceBrowser(peer: peerID, serviceType: "realm-tv")
        client?.delegate = self
        client?.startBrowsingForPeers()

    }
}

class PartialPresentationSegue: UIStoryboardSegue {
    override func perform() {
        source.present(destination, animated: true, completion: nil)
    }
}

private class PartialPresentationController: UIPresentationController {
    private override var frameOfPresentedViewInContainerView: CGRect { get {
        let height = CGFloat(300.0)
        return CGRect(x: 0, y: presentingViewController.view.frame.height-height, width: presentingViewController.view.frame.width, height: height)
        }
    }
}

extension ViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return PartialPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

extension ViewController: PlaybackControlsViewControllerDelegate {
    func updateSlide(attributes: [String: Int]) {
        var attributesJSON = [String: JSON]()
        for (key, value) in attributes {
            attributesJSON[key] = .int(value)
        }
        if let peers = session?.connectedPeers, let data = try? JSON.dictionary(attributesJSON).serialize() {
            try? session?.send(data, toPeers: peers, with: .reliable)
        }
    }
    
    func toggleTranscript(followsVideoProgress: Bool) {
        transcriptShouldFollow = followsVideoProgress
    }
    
    func adjustPlayback(speed: Float) {
        if let peers = session?.connectedPeers, let data = try? JSON.dictionary(["playback-speed": .double(Double(speed))]).serialize() {
            try? session?.send(data, toPeers: peers, with: .reliable)
        }
    }
}

extension ViewController: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        dump("\(#function) \(browser) \(peerID)")
    }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        dump("\(#function) \(browser) \(peerID) \(info)")
        guard let session = self.session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 0)
    }
}

extension ViewController: MCSessionDelegate {
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        dump("\(#function) \(session) \(peerID) \(streamName) \(stream)")
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        dump("\(#function) \(session) \(resourceName) \(peerID) \(progress)")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        dump("\(#function) \(session) \(resourceName) \(peerID) \(localURL) \(error)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        dump("\(#function) \(session) \(peerID) \(data)")
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            dump(json)
            handleJSON(json: data)
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        dump("\(#function) \(session) \(peerID) \(state)")
    }
}
