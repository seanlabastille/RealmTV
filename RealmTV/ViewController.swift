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
    @IBOutlet weak var talksTableView: UITableView!
    
    var items = [FeedItem]()
    var onceToken = dispatch_once_t()
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        dispatch_once(&onceToken) {
        realmFeedItems { items in
            items.prefix(50).forEach { item in
                item.addTalkDetails { item in
                    if item.talk != nil {
                    self.items.append(item)
                    self.talksTableView.reloadData()
                    }
                }
            }
        }
        }
    }

}

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.row < items.count {
            if items[indexPath.row].talk != nil {
                let talkViewController = TalkViewController(feedItem: items[indexPath.row])
                self.presentViewController(talkViewController, animated: true, completion: nil)
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

