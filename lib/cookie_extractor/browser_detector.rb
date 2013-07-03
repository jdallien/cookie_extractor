module CookieExtractor
  class BrowserNotDetectedException < Exception; end
  class InvalidBrowserNameException < Exception; end
  class NoCookieFileFoundException < Exception; end

  class BrowserDetector
    COOKIE_LOCATIONS = {
      "chrome" => "~/.config/google-chrome/Default/Cookies",
      "chromium" => "~/.config/chromium/Default/Cookies",
      "firefox" => "~/.mozilla/firefox/*.default/cookies.sqlite"
    }

    # Returns the extractor of the most recently used browser's cookies
    #   or raise NoCookieFileFoundException if there are no cookies
    def self.guess
      most_recently_used_detected_browsers.each { |browser, path|
        begin
          extractor = self.browser_extractor(browser)
        rescue BrowserNotDetectedException, NoCookieFileFoundException
          # better try the next one...
        else
          return extractor
        end
      }
      # If we make it here, we've failed...
      raise NoCookieFileFoundException, "Couldn't find any browser's cookies"
    end

    # Open a browser's cookie file using intelligent guesswork
    def self.browser_extractor(browser)
      raise InvalidBrowserNameException, "Browser must be one of: #{self.supported_browsers.join(', ')}" unless self.supported_browsers.include?(browser)
      paths = Dir.glob(File.expand_path(COOKIE_LOCATIONS[browser]))
      if paths.length < 1 or not File.exists?(paths.first)
        raise NoCookieFileFoundException, "File #{paths.first} does not exist!"
      end
      self.new_extractor(paths.first)
    end

    def self.new_extractor(db_filename)
      browser = detect_browser(db_filename)
      if browser
        CookieExtractor.const_get("#{browser}CookieExtractor").new(db_filename)
      else
        raise BrowserNotDetectedException, "Could not detect browser type."
      end
    end

    def self.supported_browsers
      COOKIE_LOCATIONS.keys
    end

    def self.detect_browser(db_filename)
      db = SQLite3::Database.new(db_filename)
      browser = 
        if has_table?(db, 'moz_cookies')
          'Firefox'
        elsif has_table?(db, 'cookies')
          'Chrome'
        end
      db.close
      browser
    end

    def self.has_table?(db, table_name)
      db.table_info(table_name).size > 0
    end

    def self.most_recently_used_detected_browsers
      COOKIE_LOCATIONS.select { |browser, path|
        Dir.glob(File.expand_path(path)).any?
      }.sort_by { |browser, path|
        File.mtime(Dir.glob(File.expand_path(path)).first)
      }.reverse
    end

    private_class_method :most_recently_used_detected_browsers
  end
end
