$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require "cookie_extractor/version"
require "cookie_extractor/common"
require "cookie_extractor/firefox_cookie_extractor"
require "cookie_extractor/chrome_cookie_extractor"
require "cookie_extractor/browser_detector"

module CookieExtractor
end
