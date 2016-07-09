//
//  ViewController.swift
//  RealmTV
//
//  Created by Seán Labastille on 10/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import UIKit
import AVKit
import AsyncNetwork

class ViewController: UITableViewController {
    static var talksFetched = false
    @IBOutlet weak var talksPosterImageView: UIImageView!
    @IBOutlet weak var talksTitleLabel: UILabel!
    @IBOutlet weak var talkDescriptionLabel: UILabel!
    @IBOutlet weak var talksTableView: UITableView!
    
    var server: AsyncServer?
    var items = [FeedItem]()
    var connections = [AsyncConnection]()
    var onceToken = Int()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        server = AsyncServer()
        server?.serviceName = "Realm TV"
        server?.delegate = self
        server?.start()
        
        fetchTalks()
    }
    
    
    // MARK: Realm talk feed processing
    func fetchTalks() {
        if !ViewController.talksFetched {
            realmFeedItems { items in
                items.prefix(upTo: 50).forEach { item in
                    DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosUserInitiated).async {
                        item.addTalkDetails(self.itemWithTalkDetailsHandler)
                    }
                }
            }
            ViewController.talksFetched = true
        }
    }
    
    func itemWithTalkDetailsHandler(_ item: FeedItem) {
        guard item.talk != nil else { return }
        var items = self.items
        items.append(item)
        items.sort { (item1, item2) -> Bool in
            return item1.date.compare(item2.date) != .orderedAscending
        }
        self.items = items
        self.tableView.reloadData()
    }
}

extension ViewController { // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let nextFocusedIndexPath = context.nextFocusedIndexPath where
        (nextFocusedIndexPath as NSIndexPath).row < items.count,
            let item = Optional.some(items[(nextFocusedIndexPath as NSIndexPath).row]) {
            // FIXME: Tell detail view controller about focused talk
            /*talksTitleLabel.text = item.title
            talkDescriptionLabel.text = item.description
            DispatchQueue.global(attributes: [DispatchQueue.GlobalAttributes.qosUserInitiated]).async {
                if let slide = item.talk?[slide: 0] {
                    DispatchQueue.main.async {
                        self.talksPosterImageView.image = slide
                    }
                }
            }*/
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row < items.count && items[(indexPath as NSIndexPath).row].talk != nil  {
            let feedItem = items[(indexPath as NSIndexPath).row]
            let talkViewController = TalkViewController(feedItem: feedItem)
            talkViewController.talkDelegate = self
            self.present(talkViewController, animated: true, completion: nil)
            connections.forEach { connection in
                if connection.connected {
                    connection.sendCommand(2, object: NSDictionary(dictionary: ["talk-begin": try! feedItem.toJSON().serialize() ?? "missing talk id"]))
                }
            }
        }
    }
}

extension ViewController { // MARK: UITableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "talk"),
               itemIndex = Optional.some((indexPath as NSIndexPath).row) where itemIndex < items.count {
            cell.textLabel?.text = items[itemIndex].title
            cell.detailTextLabel?.text = items[itemIndex].description
            return cell
        }
        fatalError()
    }
}

extension ViewController: TalkViewControllerDelegate {
    func talkCurrentTimeChanged(_ talkViewController: TalkViewController, currentTime: TimeInterval) {
        connections.forEach { connection in
            if connection.connected {
                connection.sendCommand(3, object: ["talk-time": currentTime])
            }
        }
    }
}

public func /= ( sizeToScale: inout CGSize, denominator: CGFloat) {
    sizeToScale = CGSize(width: sizeToScale.width/denominator, height: sizeToScale.height/denominator)
}

extension ViewController: AsyncServerDelegate {
    func server(_ theServer: AsyncServer!, didConnect connection: AsyncConnection!) {
        connections.append(connection)
    }
    
    func server(_ theServer: AsyncServer!, didDisconnect connection: AsyncConnection!) {
        if let index = connections.index(of: connection) {
            connections.remove(at: index)
        }
    }
    
    func server(_ theServer: AsyncServer!, didReceiveCommand command: AsyncCommand, object: AnyObject!, connection: AsyncConnection!) {
        print("\(theServer) \(command) \(object) \(connection)")
        if command == 1 {
            if let tvc = presentedViewController as? TalkViewController {
                var slideSize = self.view.bounds.size
                switch String(object["slide-size"] as! NSNumber) {
                case "1":
                    slideSize /= 4
                case "2":
                    slideSize /= 3
                case "3":
                    slideSize /= 2
                case "0":
                    fallthrough
                default:
                    slideSize = CGSize.zero
                }
                switch String(object["slide-position"] as! NSNumber) {
                case "0":
                    tvc.slideOverlayView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: slideSize)
                case "1":
                    tvc.slideOverlayView?.frame = CGRect(origin: CGPoint(x: 1920-slideSize.width, y: 0), size: slideSize)
                case "2":
                    tvc.slideOverlayView?.frame = CGRect(origin: CGPoint(x: 0, y: 1080-slideSize.height), size: slideSize)
                case "3":
                    tvc.slideOverlayView?.frame = CGRect(origin: CGPoint(x: 1920-slideSize.width, y: 1080-slideSize.height), size: slideSize)
                default:
                    break
                }
            }
        }
    }
}

