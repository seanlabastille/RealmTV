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
import Freddy

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

// MARK: Freddy serialization extensions

extension FeedItem: JSONDecodable, JSONEncodable {
    init(json value: JSON) throws {
        title = try value.string("title")
        description = try value.string("description")
        date = NSDateFormatter().dateFromString(try value.string("date"))!
        url = NSURL(string: try value.string("url"))!
        talk = try Talk(json: value.array("talk").first ?? .Null)
    }
    
    func toJSON() -> JSON {
        return .Dictionary([
            "title": .String(title),
            "description": .String(description),
            "date": .String(NSDateFormatter().stringFromDate(date)),
            "url": .String(url.absoluteString),
            "talk": .Array([talk?.toJSON() ?? .Null])
            ])
    }
}

extension Talk: JSONEncodable, JSONDecodable {
    init(json value: JSON) throws {
        videoURL = try NSURL(string: value.string("videoURL"))!
        slidesURL = try NSURL(string: value.string("slidesURL"))!
        slideTimes = [:]
    }
    
    func toJSON() -> JSON {
        return .Dictionary([
            "videoURL": .String(videoURL.absoluteString),
            "slidesURL": .String(slidesURL.absoluteString)
            ])
    }
}

// MARK: Feed fetching

func realmFeedItems(completion: ([FeedItem] -> ())) {
    let url = "https://realm.io/feed.xml"
    
    Alamofire.request(.GET, url).responseRSS() { response in
        if let feed: RSSFeed = response.result.value {
            var feedItems: [FeedItem] = []
            for item in feed.items {
                feedItems.append(FeedItem(title: item.title!, description: item.itemDescription!, date: item.pubDate!, url: NSURL(string: item.guid!)!, talk: nil))
            }
            completion(feedItems)
        }
    }
}

// MARK: Populate talk details

struct RealmTalkMetadata: JSONDecodable {
    init(json: JSON) throws {
        title = try json.string("title")
        chapters = try json.arrayOf("chapters")
    }
    
    let title: String
    let chapters: [RealmTalkMetadataChapter]
}

struct RealmTalkMetadataChapter: JSONDecodable {
    init(json: JSON) throws {
        title = try json.string("title")
        duration = try json.int("duration")
        video = try RealmTalkMetadataChapterVideo(json: json["video"] ?? .Null)
        slides = try json.arrayOf("slides")
    }
    
    let title: String
    let duration: Int
    let video: RealmTalkMetadataChapterVideo
    let slides: [RealmTalkMetadataChapterSlide]
}

struct RealmTalkMetadataChapterVideo {
    init(json: JSON) throws {
        url = try json.string("url")
    }
    
    let url: String
}

struct RealmTalkMetadataChapterSlide: JSONDecodable {
    init(json: JSON) throws {
        url = try json.string("url")
        time = try json.int("time")
    }
    
    let url: String
    let time: Int
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
                    guard let idMatchRange = matches.first?.rangeAtIndex(1) else { return }
                    let matchStartIndex = nodeContent.startIndex.advancedBy(idMatchRange.location)
                    let matchEndIndex = nodeContent.startIndex.advancedBy(NSMaxRange(idMatchRange))
                    let videoID = nodeContent.substringWithRange(matchStartIndex..<matchEndIndex)
                    guard let videoManifestURL = NSURL(string: "https://realm.io/assets/videos/\(videoID).json") else { return }
                    
                    if let jsonData = try? NSData(contentsOfURL: videoManifestURL, options: []),
                        let metadata = try? RealmTalkMetadata(json: JSON(data: jsonData)),
                        firstChapter = metadata.chapters.first {
                        
                        var slidesURL = ""
                        var timings: [NSTimeInterval:Int] = [:]
                        for slide in firstChapter.slides {
                            if let fragmentRange = slide.url.rangeOfString("#") {
                                slidesURL = slide.url
                                let slideTime = NSTimeInterval(slide.time)
                                let slideNumber = slide.url.substringFromIndex(fragmentRange.startIndex.successor())
                                timings[slideTime] = Int(slideNumber)
                            }
                        }
                        
                        guard let videoURL = NSURL(string: firstChapter.video.url) else { return }
                        print("Materializing video URL \(videoURL) for talk \(title)")
                        materializeVideoURL(videoURL) { url in
                            var vitem = self
                            vitem.talk = Talk(videoURL: url!, slidesURL: NSURL(string: slidesURL)!, slideTimes: timings)
                            talkFound?(vitem)
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
                        let a1080pAssets = assets.filter { asset in
                            if let displayName = asset["display_name"] as? String {
                                return displayName == "1080p"
                            } else {
                                return false
                            }
                        }
                        if let firstAsset = a1080pAssets.first,
                               urlString = firstAsset["url"] as? String {
                            completion(NSURL(string: urlString))
                        }
                    }
                }
            }
        default:
            dump("Unhandled video host: \(videoURL.host)")
        }
    }
    
    
}

// MARK: Talk support

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