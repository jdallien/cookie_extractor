require 'sqlite3'

module CookieExtractor
  class FirefoxCookieExtractor
    include Common

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract
      db = SQLite3::Database.new @cookie_file
      db.results_as_hash = true
      result = []
      db.execute("SELECT * FROM moz_cookies") do |row|
        result << [ row['host'],
          true_false_word(is_domain_wide(row['host'])),
          row['path'],
          true_false_word(row['isSecure']),
          row['expiry'],
          row['name'],
          row['value']
        ].join("\t")
      end
      db.close
      result
    end
  end
end
