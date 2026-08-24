require 'sqlite3'

module CookieExtractor
  class ChromeCookieExtractor
    include Common

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract(format: :netscape, domain: nil)
      db = SQLite3::Database.new @cookie_file
      db.results_as_hash = true
      result = []
      db.execute("SELECT * FROM cookies") do |row|
        next unless domain.nil? || cookie_applies?(row['host_key'], domain)

        secure = row.key?('is_secure') ? row['is_secure'] : row['secure']
        result << cookie_line(row['host_key'], row['path'], secure, row['expires_utc'], row['name'], row['value'], format: format)
      end
      db.close
      result
    end
  end
end
