//
//  ViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 10/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit
import AVKit
import MultipeerConnectivity
import Freddy

public extension CGSize {
    static public func /= ( sizeToScale: inout CGSize, denominator: CGFloat) {
        sizeToScale = CGSize(width: sizeToScale.width/denominator, height: sizeToScale.height/denominator)
    }
}

class TalkListViewController: UITableViewController {
    static var talksFetched = false

    var advertiser: MCNearbyServiceAdvertiser?
    var session: MCSession?

    var items = [FeedItem]()
    var onceToken = Int()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Realm TV"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let peerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: peerID)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "realm-tv")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        fetchTalks()
    }
    
    
    // MARK: Realm talk feed processing
    func fetchTalks() {
        if !TalkListViewController.talksFetched {
            realmFeedItems { items in
                items.prefix(upTo: 100).forEach { item in
                    DispatchQueue.global(qos: .userInitiated).async {
                        item.addTalkDetails(self.itemWithTalkDetailsHandler)
                    }
                }
            }
            TalkListViewController.talksFetched = true
        }
    }

    
    
    func itemWithTalkDetailsHandler(_ item: FeedItem) {
        guard item.talk != nil else { return }
        var items = self.items
        items.append(item)
//        items.sort(by: <) // FIXME
        self.items = items
        self.tableView.reloadData()
    }
}

extension TalkListViewController { // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextFocusedIndexPath = context.nextFocusedIndexPath ,
        (nextFocusedIndexPath as NSIndexPath).row < items.count,
            let item = Optional.some(items[(nextFocusedIndexPath as NSIndexPath).row]) {
            if let detailNavigationController = self.splitViewController?.viewControllers[1] as? UINavigationController,
                   let detailViewController = detailNavigationController.viewControllers.first as? TalkDetailViewController {
                detailViewController.feedItem = item
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row < items.count && items[(indexPath as NSIndexPath).row].talk != nil  {
            let feedItem = items[(indexPath as NSIndexPath).row]
            let talkViewController = TalkViewController(feedItem: feedItem)
            talkViewController.talkDelegate = self
            self.present(talkViewController, animated: true, completion: nil)

            do {
                let data = try JSON.dictionary(["talk-begin": feedItem.toJSON()]).serialize()
                if let peers = session?.connectedPeers {
                    try? session?.send(data, toPeers: peers, with: .reliable)
                }
            } catch {
                dump(error)
            }
        }
    }
}

extension TalkListViewController { // MARK: UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "talk"),
               let itemIndex = Optional.some((indexPath as NSIndexPath).row) , itemIndex < items.count {
            cell.textLabel?.text = items[itemIndex].title
            cell.detailTextLabel?.text = items[itemIndex].description
            return cell
        }
        fatalError()
    }
}

extension TalkListViewController: TalkViewControllerDelegate {
    func talkCurrentTimeChanged(_ talkViewController: TalkViewController, currentTime: TimeInterval) {
        if currentTime.truncatingRemainder(dividingBy: 5) == 0 {
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                let items = self.items
                let item = items[selectedIndexPath.row]
                if let data = try? JSON.dictionary(["talk-begin": item.toJSON()]).serialize() {
                    if let peers = session?.connectedPeers {
                        try? session?.send(data, toPeers: peers, with: .reliable)
                    }
                }
            }
        }

        if let data = try? JSON.dictionary(["talk-time": JSON.double(currentTime)]).serialize(), let peers = session?.connectedPeers {
            try? session?.send(data, toPeers: peers, with: .reliable)
        }
    }
}

extension TalkListViewController { // MARK: Command Handling
    func handleJSON(json data: Data) {
        guard let talkViewController = presentedViewController as? TalkViewController else { return }
        if let freddyJSON = try? JSON(data: data),
            let slideSize = try? freddyJSON.getInt(at: "slide-size"),
            let slidePosition = try? freddyJSON.getInt(at: "slide-position") {
            dump("Slide adjustment: \(slideSize) \(slidePosition)")
            let windowBounds = UIApplication.shared.keyWindow!.bounds
            var slideDimensions = windowBounds.size
            if (1...3).contains(slideSize) {
                slideDimensions /= (CGFloat(5-slideSize))
            } else {
                slideDimensions = CGSize.zero
            }
            var slideFrame = CGRect(origin: CGPoint.zero, size: slideDimensions)
            switch slidePosition {
            case 1:
                slideFrame = CGRect(origin: CGPoint(x: windowBounds.size.width-slideDimensions.width, y: 0), size: slideDimensions)
            case 2:
                slideFrame = CGRect(origin: CGPoint(x: 0, y: windowBounds.size.height-slideDimensions.height), size: slideDimensions)
            case 3:
                slideFrame = CGRect(origin: CGPoint(x: windowBounds.size.width-slideDimensions.width, y: windowBounds.size.height-slideDimensions.height), size: slideDimensions)
            default:
                break
            }
            DispatchQueue.main.async {
                talkViewController.slideOverlayView?.frame = slideFrame
            }
        }

        if let freddyJSON = try? JSON(data: data),
            let playbackSpeed = try? freddyJSON.getDouble(at: "playback-speed") {
            dump("Playback speed: \(playbackSpeed) ")
            DispatchQueue.main.async {
                talkViewController.player?.rate = Float(playbackSpeed)
            }
        }
    }
}

extension TalkListViewController: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        dump("\(#function) \(advertiser) \(peerID) \(context)")
        invitationHandler(true, self.session)
    }
}

extension TalkListViewController: MCSessionDelegate {
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
