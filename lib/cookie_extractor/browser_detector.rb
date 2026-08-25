require_relative 'common'

module CookieExtractor
  class BrowserNotDetectedException < Exception; end
  class InvalidBrowserNameException < Exception; end
  class NoCookieFileFoundException < Exception; end

  class BrowserDetector
    CHROMIUM_BROWSERS = %w[chrome chromium].freeze
    SUPPORTED_BROWSERS = (CHROMIUM_BROWSERS + %w[firefox]).freeze

    # Returns the extractor of the most recently used browser's cookies
    #   or raise NoCookieFileFoundException if there are no cookies
    def self.guess
      most_recently_used_detected_browsers.each { |path|
        begin
          extractor = self.browser_extractor(nil, path)
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
    def self.browser_extractor(browser, path = nil)
      raise InvalidBrowserNameException, "Browser must be one of: #{self.supported_browsers.join(', ')}" unless browser.nil? || self.supported_browsers.include?(browser)
      paths = path.nil? ? most_recently_used(cookie_locations(browser)) : [path]
      if paths.length < 1 or not File.exist?(paths.first)
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
      SUPPORTED_BROWSERS
    end

    def self.detect_browser(db_filename)
      browser = nil
      Common::with_sqlite(db_filename) do |db|
        browser =
          if has_table?(db, 'moz_cookies')
            'Firefox'
          elsif has_table?(db, 'cookies')
            'Chrome'
          end
      end
      browser
    end

    def self.has_table?(db, table_name)
      db.table_info(table_name).size > 0
    end

    def self.cookie_locations(browser = nil)
      browsers = browser.nil? ? supported_browsers : [browser]
      locations = []
      locations << "~/.config/google-chrome/Default/Cookies" if browsers.include?("chrome")
      locations << "~/.config/chromium/Default/Cookies" if browsers.include?("chromium")
      if browsers.include?("firefox")
        locations << "~/.mozilla/firefox/*.*default*/cookies.sqlite"
        locations << "~/.mozilla/firefox/*.Profile*/cookies.sqlite"
      end
      locations
    end

    def self.most_recently_used_detected_browsers
      most_recently_used(cookie_locations)
    end

    def self.most_recently_used(paths)
      paths.flat_map { |path|
        Dir.glob(File.expand_path(path))
      }.sort_by { |path|
        File.mtime(path)
      }.reverse
    end

    private_class_method :most_recently_used_detected_browsers
  end
end
