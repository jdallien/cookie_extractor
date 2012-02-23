require 'sqlite3'

module CookieExtractor
  class ChromeCookieExtractor
    include Common

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract
      db = SQLite3::Database.new @cookie_file
      db.results_as_hash = true
      result = []
      db.execute("SELECT * FROM cookies") do |row|
        result << [ row['host_key'],
          true_false_word(is_domain_wide(row['host_key'])),
          row['path'],
          true_false_word(row['secure']),
          row['expires_utc'],
          row['name'],
          row['value']
        ].join("\t")
      end
      db.close
      result
    end
  end
end
