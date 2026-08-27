require_relative 'common'

module CookieExtractor
  class BrowserNotDetectedException < Exception; end
  class InvalidBrowserNameException < Exception; end
  class NoCookieFileFoundException < Exception; end

  class BrowserDetector
    CHROMIUM_APPS = %w[chrome chromium].freeze
    SUPPORTED_APPS = (CHROMIUM_APPS + %w[firefox]).freeze

    # Returns the extractor of the most recently used browser's cookies
    #   or raise NoCookieFileFoundException if there are no cookies
    def self.guess(secrets: [])
      most_recently_used_detected_browsers.each { |path|
        begin
          extractor = self.browser_extractor(nil, path: path, secrets: secrets)
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
    def self.browser_extractor(app, path: nil, secrets: [])
      raise InvalidBrowserNameException, "App/Browser must be one of: #{self.supported_apps.join(', ')}" unless app.nil? || self.supported_apps.include?(app)
      paths = path.nil? ? most_recently_used(cookie_locations(app)) : [path]
      if paths.length < 1 or not File.exist?(paths.first)
        raise NoCookieFileFoundException, "File #{paths.first} does not exist!"
      end
      self.new_extractor(paths.first, app: app, secrets: secrets)
    end

    def self.new_extractor(db_filename, app: nil, secrets: [])
      browser = detect_browser(db_filename)
      if browser
        app = detect_app(db_filename) unless app
        CookieExtractor.const_get("#{browser}CookieExtractor").new(db_filename, app: app, secrets: secrets)
      else
        raise BrowserNotDetectedException, "Could not detect browser type."
      end
    end

    def self.supported_apps
      SUPPORTED_APPS
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

    def self.detect_app(db_filename)
      case db_filename.split('/')[-3]
      when 'firefox'
        :firefox
      when 'google-chrome'
        :chrome
      when 'chromium'
        :chromium
      else
        # Unknown so fallback as chromium
        :chromium
      end
    end

    def self.has_table?(db, table_name)
      db.table_info(table_name).size > 0
    end

    def self.cookie_locations(app = nil)
      apps = app.nil? ? supported_apps : [app]
      locations = []
      locations << "~/.config/google-chrome/Default/Cookies" if apps.include?("chrome")
      locations << "~/.config/chromium/Default/Cookies" if apps.include?("chromium")
      if apps.include?("firefox")
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
