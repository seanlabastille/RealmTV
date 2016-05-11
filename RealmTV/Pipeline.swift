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
    func addTalkDetails(talkFound: (FeedItem -> ())? = nil) {
        let jiDoc = Ji(htmlURL: url)
        if let scriptNodes = jiDoc?.xPath("//script") {
            for node in scriptNodes {
                if let nodeContent = node.content,
                       _ = nodeContent.rangeOfString("setupVideo") {
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
                            var slidesURL = ""
                            var timings: [NSTimeInterval:Int] = [:]
                            for slide in firstChapterSlides {
                                if let slideURL = (slide["url"] ?? "") as? String,
                                       fragmentRange = slideURL.rangeOfString("#") {
                                    slidesURL = slideURL
                                    let slideTime = (slide["time"] ?? -1) as! NSTimeInterval
                                    let slideNumber = slideURL.substringFromIndex(fragmentRange.startIndex.successor())
                                    timings[slideTime] = Int(slideNumber)
                                }
                            }
                            materializeVideoURL(NSURL(string:videoURL)!) { url in
                                var vitem = self
                                vitem.talk = Talk(videoURL: url!, slidesURL: NSURL(string: slidesURL)!, slideTimes: timings)
                                talkFound?(vitem)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func materializeVideoURL(videoURL: NSURL, completion: (NSURL? -> ())) {
        switch videoURL.host {
        case .Some("realm.wistia.com"):
            let request = NSMutableURLRequest(URL: NSURL(string: "https://fast.wistia.net/embed/iframe/\(videoURL.lastPathComponent ?? "")")!)
            request.addValue("\(videoURL)", forHTTPHeaderField: "Referer")
            Alamofire.request(request).response { (request,response,responseData,error) in
                let responseString = String(data: responseData!, encoding: NSUTF8StringEncoding)!
                let iFrameInitRegex = try! NSRegularExpression(pattern: "Wistia\\.iframeInit\\((\\{.*), \\{\\}\\)", options: [])
                let matches = iFrameInitRegex.matchesInString(responseString, options: [], range: NSMakeRange(0, responseString.characters.count))
                //dump(matches)
                if let firstMatch = matches.first {
                    let matchStartIndex = responseString.startIndex.advancedBy(firstMatch.rangeAtIndex(1).location)
                    let matchEndIndex = responseString.startIndex.advancedBy(NSMaxRange(firstMatch.rangeAtIndex(1)))
                    let iframeInitJSON = responseString.substringWithRange(matchStartIndex..<matchEndIndex).dataUsingEncoding(NSUTF8StringEncoding)
                    let json = try! NSJSONSerialization.JSONObjectWithData(iframeInitJSON!, options: [])
                    // display_name: "1080p"
                    if let assets = json["assets"] as? Array<AnyObject> {
                        let a1080pAsset = assets.filter { asset in
                            if let displayName = asset["display_name"] as? String {
                                return displayName == "1080p"
                            } else {
                                return false
                            }
                    }.first
                        if let urlString = a1080pAsset!["url"] as? String {
                            completion(NSURL(string: urlString))
                        }
                    }
                }
//                completion(nil)
            }
        default:
            dump("Unhandled video host: \(videoURL.host)")
        }
    }
    
    
}

extension Talk {
    var presentationID: String? {
        get {
            return slidesURL.path?.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "/"))
        }
    }
    subscript(slide slide: Int) -> UIImage? {
        if slide < slideTimes.count {
            let group = dispatch_group_create()
            var image: UIImage?
            dispatch_group_enter(group)
            let slideURLString = "https://speakerd.s3.amazonaws.com/presentations/\(presentationID ?? "")/slide_\(slide).jpg"
            Alamofire.request(.GET, slideURLString).responseData(completionHandler: { (response) in
                if let data = response.data, i = UIImage(data: data) {
                    image = i
                }
                dispatch_group_leave(group)
            })
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
            return image
        } else {
            return nil
        }
    }
}