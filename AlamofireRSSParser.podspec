Pod::Spec.new do |s|
s.name             = "AlamofireRSSParser"
s.version          = "1.0.2-tv"
s.summary          = "An RSS parser response handler for Alamofire"

s.description      = "An RSS parser plugin for Alamofire.  Adds a \"responseRSS()\" responseHandler to Alamofire."

s.homepage         = "https://github.com/AdeptusAstartes/AlamofireRSSParser"
s.license          = 'MIT'
s.author           = { "Don Angelillo" => "dangelillo@gmail.com" }
s.source           = { :git => "https://github.com/AdeptusAstartes/AlamofireRSSParser.git", :tag => "1.0.2" }

s.ios.deployment_target = '8.0'
s.tvos.deployment_target = '9.0'
s.requires_arc = true

s.source_files = 'Pod/Classes/**/*'
s.resource_bundles = {
  'AlamofireRSS' => ['Pod/Assets/*.png']
}

s.dependency 'Alamofire', '~> 3.3.0'
end