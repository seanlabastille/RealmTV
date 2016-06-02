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

class ViewController: UIViewController {
    @IBOutlet weak var talksPosterImageView: UIImageView!
    @IBOutlet weak var talksTitleLabel: UILabel!
    @IBOutlet weak var talkDescriptionLabel: UILabel!
    @IBOutlet weak var talksTableView: UITableView!
    
    var server: AsyncServer?
    var items = [FeedItem]()
    var connections = [AsyncConnection]()
    var onceToken = dispatch_once_t()
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        server = AsyncServer()
        server?.serviceName = "Realm TV"
        server?.delegate = self
        server?.start()
        
        dispatch_once(&onceToken) {
            realmFeedItems { items in
                items.prefix(50).forEach { item in
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                        item.addTalkDetails { item in
                            if item.talk != nil {
                                var items = self.items
                                items.append(item)
                                items.sortInPlace({ (item1, item2) -> Bool in
                                    return item1.date.compare(item2.date) != .OrderedAscending
                                })
                                self.items = items
                                self.talksTableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
    }
    
}

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didUpdateFocusInContext context: UITableViewFocusUpdateContext, withAnimationCoordinator coordinator: UIFocusAnimationCoordinator) {
        if let nextFocusedIndexPath = context.nextFocusedIndexPath where
        nextFocusedIndexPath.row < items.count,
            let item = Optional.Some(items[nextFocusedIndexPath.row]) {
            talksTitleLabel.text = item.title
            talkDescriptionLabel.text = item.description
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                if let slide = item.talk?[slide: 0] {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.talksPosterImageView.image = slide
                    }
                }
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row < items.count {
            if items[indexPath.row].talk != nil {
                let feedItem = items[indexPath.row]
                let talkViewController = TalkViewController(feedItem: feedItem)
                talkViewController.talkDelegate = self
                self.presentViewController(talkViewController, animated: true, completion: nil)
                connections.forEach({ (connection) in
                    if connection.connected {
                        connection.sendCommand(2, object: ["talk-begin": try! feedItem.toJSON().serialize() ?? "missing talk id"])
                    }
                })
            }
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCellWithIdentifier("talk"),
               itemIndex = Optional.Some(indexPath.row) where itemIndex < items.count {
            cell.textLabel?.text = items[itemIndex].title
            cell.detailTextLabel?.text = items[itemIndex].description
            return cell
        }
        fatalError()
    }
}

extension ViewController: TalkViewControllerDelegate {
    func talkCurrentTimeChanged(talkViewController: TalkViewController, currentTime: NSTimeInterval) {
        connections.forEach({ (connection) in
            if connection.connected {
                connection.sendCommand(3, object: ["talk-time": currentTime])
            }
        })
    }
}

extension ViewController: AsyncServerDelegate {
    func server(theServer: AsyncServer!, didConnect connection: AsyncConnection!) {
        connections.append(connection)
    }
    
    func server(theServer: AsyncServer!, didDisconnect connection: AsyncConnection!) {
        if let index = connections.indexOf(connection) {
            connections.removeAtIndex(index)
        }
    }
    
    func server(theServer: AsyncServer!, didReceiveCommand command: AsyncCommand, object: AnyObject!, connection: AsyncConnection!) {
        print("\(theServer) \(command) \(object) \(connection)")
        if command == 1 {
            if let tvc = presentedViewController as? TalkViewController {
                let slideSize: CGSize
                switch String(object["slide-size"] as! NSNumber) {
                case "1":
                    slideSize = CGSize(width: self.view.bounds.width/4, height: self.view.bounds.height/4)
                case "2":
                    slideSize = CGSize(width: self.view.bounds.width/3, height: self.view.bounds.height/3)
                case "3":
                    slideSize = CGSize(width: self.view.bounds.width/2, height: self.view.bounds.height/2)
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

