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
    let date: Date
    let url: URL
    var talk: Talk?

    static func <(lhs: FeedItem, rhs: FeedItem) -> Bool {
        return lhs.date.compare(rhs.date) != .orderedAscending
    }
}

struct Talk {
    let videoURL: URL
    let slidesURL: URL
    let slideTimes: [TimeInterval:Int]
}

// MARK: Freddy serialization extensions

extension FeedItem: JSONDecodable, JSONEncodable {
    init(json value: JSON) throws {
        title = try value.getString(at: "title")
        description = try value.getString(at: "description")
        date = DateFormatter().date(from: try value.getString(at: "date"))!
        url = NSURL(string: try value.getString(at: "url"))! as URL
        talk = try Talk(json: value.getArray(at: "talk").first ?? .null)
    }
    
    func toJSON() -> JSON {
        return .dictionary([
            "title": .string(title),
            "description": .string(description),
            "date": .string(DateFormatter().string(from: date)),
            "url": .string(url.absoluteString),
            "talk": .array([talk?.toJSON() ?? .null])
            ])
    }
}

extension Talk: JSONEncodable, JSONDecodable {
    init(json value: JSON) throws {
        videoURL = try NSURL(string: value.getString(at: "videoURL"))! as URL
        slidesURL = try NSURL(string: value.getString(at: "slidesURL"))! as URL
        slideTimes = [:]
    }
    
    func toJSON() -> JSON {
        return .dictionary([
            "videoURL": .string(videoURL.absoluteString),
            "slidesURL": .string(slidesURL.absoluteString)
            ])
    }
}

// MARK: Feed fetching

func realmFeedItems(_ completion: @escaping (([FeedItem]) -> ())) {
    let url = "https://realm.io/feed.xml"
    
    _ = Alamofire.request(url).responseRSS() { response in
        if let feed = response.value {
            var feedItems: [FeedItem] = []
            for item in feed.items {
                feedItems.append(FeedItem(title: item.title!, description: item.itemDescription!, date: item.pubDate!, url: NSURL(string: item.guid!)! as URL, talk: nil))
            }
            completion(feedItems)
        }
    }
}

// MARK: Populate talk details

struct RealmTalkMetadata: JSONDecodable {
    init(json: JSON) throws {
        title = try json.getString(at: "title")
        chapters = try json.getArray(at: "chapters").map(RealmTalkMetadataChapter.init)
    }
    
    let title: String
    let chapters: [RealmTalkMetadataChapter]
}

struct RealmTalkMetadataChapter: JSONDecodable {
    init(json: JSON) throws {
        title = try json.getString(at: "title")
        duration = try json.getInt(at: "duration")
        video = try RealmTalkMetadataChapterVideo(json: json["video"] ?? .null)
        slides = try json.getArray(at: "slides").map(RealmTalkMetadataChapterSlide.init)
    }
    
    let title: String
    let duration: Int
    let video: RealmTalkMetadataChapterVideo
    let slides: [RealmTalkMetadataChapterSlide]
}

struct RealmTalkMetadataChapterVideo {
    init(json: JSON) throws {
        url = try json.getString(at: "url")
    }
    
    let url: String
}

struct RealmTalkMetadataChapterSlide: JSONDecodable {
    init(json: JSON) throws {
        url = try json.getString(at:"url")
        time = try json.getInt(at: "time")
    }
    
    let url: String
    let time: Int
}


extension FeedItem {
    func addTalkDetails(_ talkFound: ((FeedItem) -> ())? = nil) {
        let jiDoc = Ji(htmlURL: url)
        if let scriptNodes = jiDoc?.xPath("//script") {
            for node in scriptNodes {
                if let nodeContent = node.content,
                    let _ = nodeContent.range(of: "setupVideo") {
                    let videoIDRegularExpression = try! NSRegularExpression(pattern: "setupVideo\\(\".*\", \"(.*)\"\\);", options: [])
                    let matches = videoIDRegularExpression.matches(in: nodeContent, options: [], range: NSMakeRange(0, nodeContent.characters.count))
                    guard let idMatchRange = matches.first?.rangeAt(1) else { return }
                    let matchStartIndex = nodeContent.index(nodeContent.startIndex, offsetBy: idMatchRange.location)
                    let matchEndIndex = nodeContent.index(nodeContent.startIndex, offsetBy: NSMaxRange(idMatchRange))
                    let videoID = nodeContent.substring(with: matchStartIndex..<matchEndIndex)
                    // Looks like video manifests are now fetched from contentful
//                    guard let videoManifestURL = NSURL(string: "https://realm.io/assets/videos/\(videoID).json") else { return }
                    guard let videoManifestURL = NSURL(string: "https:\(videoID)") else { return }

                    if let jsonData = try? Data(contentsOf: videoManifestURL as URL, options: []),
                        let metadata = try? RealmTalkMetadata(json: JSON(data: jsonData as Data)),
                        let firstChapter = metadata.chapters.first {
                        
                        var slidesURL = ""
                        var timings: [TimeInterval:Int] = [:]
                        for slide in firstChapter.slides {
                            if let fragmentRange = slide.url.range(of: "#") {
                                slidesURL = slide.url
                                let slideTime = TimeInterval(slide.time)
                                timings[slideTime] = Int(slide.url[fragmentRange.upperBound ..< slide.url.endIndex])
                            }
                        }
                        
                        guard let videoURL = NSURL(string: firstChapter.video.url) else { return }
                        print("Materializing video URL \(videoURL) for talk \(title)")
                        materializeVideoURL(videoURL as URL) { url in
                            var vitem = self
                            vitem.talk = Talk(videoURL: url!, slidesURL: NSURL(string: slidesURL)! as URL, slideTimes: timings)
                            talkFound?(vitem)
                        }
                    }
                }
            }
        }
    }
    
    func materializeVideoURL(_ videoURL: URL, completion: @escaping ((URL?) -> ())) {
        switch videoURL.host {
        case .some("realm.wistia.com"):
            var request = URLRequest(url: URL(string: "https://fast.wistia.net/embed/iframe/\(videoURL.lastPathComponent)")!)
            request.addValue("\(videoURL)", forHTTPHeaderField: "Referer")
            Alamofire.request(request).response { defaultDataResponse in
                let responseString = String(data: defaultDataResponse.data!, encoding: String.Encoding.utf8)!
                let jiDoc = Ji(htmlString: responseString)
                guard let scriptNodeCount = jiDoc?.xPath("//script")?.count, scriptNodeCount >= 3 else { return }
                if let scriptContent = jiDoc?.xPath("//script")?[2].content {
                let iFrameInitRegex = try! NSRegularExpression(pattern: "Wistia\\.iframeInit\\((\\{.*\\}\\}), \\{\\}\\);$", options: [.anchorsMatchLines])
                let matches = iFrameInitRegex.matches(in: scriptContent, options: [], range: NSMakeRange(0, scriptContent.characters.count))
                if let firstMatch = matches.first {
                    let matchStartIndex = scriptContent.index(scriptContent.startIndex, offsetBy: firstMatch.rangeAt(1).location)
                    let matchEndIndex = scriptContent.index(scriptContent.startIndex, offsetBy: NSMaxRange(firstMatch.rangeAt(1)))
                    let iframeInitJSON = scriptContent.substring(with: matchStartIndex..<matchEndIndex).data(using: String.Encoding.utf8)
                    let json = try? JSONSerialization.jsonObject(with: iframeInitJSON!, options: [])
                    // display_name: "1080p"
                    if let json = json as? NSDictionary,
                        let assets = json["assets"] as? Array<AnyObject> {
                        let a1080pAssets = assets.filter { asset in
                            if let displayName = asset["display_name"] as? String {
                                return displayName == "1080p"
                            } else {
                                return false
                            }
                        }
                        if let firstAsset = a1080pAssets.first,
                               let urlString = firstAsset["url"] as? String {
                            completion(URL(string: urlString))
                        }
                    }  else {
                        dump(responseString)
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
            return slidesURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
    }
    
    subscript(slide slide: Int) -> UIImage? {
        if slide < slideTimes.count {
            let group = DispatchGroup()
            var image: UIImage?
            group.enter()
            let slideURLString = "https://speakerd.s3.amazonaws.com/presentations/\(presentationID ?? "")/slide_\(slide).jpg"
            Alamofire.request(slideURLString).responseData(completionHandler: { (response) in
                if let data = response.data, let i = UIImage(data: data) {
                    image = i
                }
                group.leave()
            })
            _ = group.wait(timeout: DispatchTime.distantFuture)
            return image
        } else {
            return nil
        }
    }
}
