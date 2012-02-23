module CookieExtractor
  class BrowserNotDetectedException < Exception; end

  class BrowserDetector

    def self.new_extractor(db_filename)
      browser = detect_browser(db_filename)
      if browser
        CookieExtractor.const_get("#{browser}CookieExtractor").new(db_filename)
      else
        raise "Could not detect browser type."
      end
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
  end
end
