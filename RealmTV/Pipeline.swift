//
//  Pipeline.swift
//  RealmTV
//
//  Created by Seán Labastille on 11/05/16.
//  Copyright © 2016 Seán Labastille. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireRSSParser
import Ji

struct FeedItem {
    let title: String
    let description: String
    let date: NSDate
    let url: NSURL
    var talk: Talk?
}

struct Talk {
    let videoURL: NSURL
    let slidesURL: NSURL
    let slideTimes: [NSTimeInterval:Int]
}

func realmFeedItems(completion: ([FeedItem] -> ())) {
    let url = "https://realm.io/feed.xml"
    
    Alamofire.request(.GET, url).responseRSS() { (response) -> Void in
        if let feed: RSSFeed = response.result.value {
            var feedItems: [FeedItem] = []
            for item in feed.items {
                feedItems.append(FeedItem(title: item.title!, description: item.itemDescription!, date: item.pubDate!, url: NSURL(string: item.link!)!, talk: nil))
            }
            completion(feedItems)
        }
    }
}

extension FeedItem {
    mutating func addTalkDetails(talkFound: (Bool -> ())? = nil) {
        let jiDoc = Ji(htmlURL: url)
        if let scriptNodes = jiDoc?.xPath("//script") {
            for node in scriptNodes {
                if let nodeContent = node.content,
                       setupVideoRange = nodeContent.rangeOfString("setupVideo") {
                    let videoIDRegularExpression = try! NSRegularExpression(pattern: "setupVideo\\(\".*\", \"(.*)\"\\);", options: [])
                    let matches = videoIDRegularExpression.matchesInString(nodeContent, options: [], range: NSMakeRange(0, nodeContent.characters.count))
                    if let idMatchRange = matches.first?.rangeAtIndex(1) {
                        let matchStartIndex = nodeContent.startIndex.advancedBy(idMatchRange.location)
                        let matchEndIndex = nodeContent.startIndex.advancedBy(NSMaxRange(idMatchRange))
                        let videoID = nodeContent.substringWithRange(matchStartIndex..<matchEndIndex)
                        let videoManifestURL = NSURL(string: "https://realm.io/videos/\(videoID).json")!
                        let jsonData = try! NSData(contentsOfURL: videoManifestURL, options: [])
                        if let videoManifestJSON = try? NSJSONSerialization.JSONObjectWithData(jsonData, options: []),
                           chapters = videoManifestJSON["chapters"] as? [AnyObject],
                           firstChapter = chapters.first,
                           firstChapterVideo = firstChapter["video"],
                           firstChapterSlides = firstChapter["slides"] as? [AnyObject] {
                            let videoURL = (firstChapterVideo?["url"] ?? "") as! String
                            var slideURL = ""
                            let timings = [:]
                            for slide in firstChapterSlides {
                                slideURL = (slide["url"] ?? "") as! String
                                // TODO: Timing
                            }
                            slideURL = slideURL.substringToIndex(slideURL.rangeOfString("#")?.startIndex ?? slideURL.endIndex)
                            talk = Talk(videoURL: NSURL(string: videoURL)!, slidesURL: NSURL(string: slideURL)!, slideTimes: [:])
                        }
                    }
                }
            }
        }
    }
}