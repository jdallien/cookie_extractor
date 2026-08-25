
require_relative 'common'

module CookieExtractor
  class FirefoxCookieExtractor
    include Common

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract(format: :netscape, domain: nil)
      result = []
      with_sqlite(@cookie_file) do |db|
        schema_version = db.get_first_value('PRAGMA user_version;').to_i
        db.execute("SELECT * FROM moz_cookies") do |row|
          next unless domain.nil? || cookie_applies?(row['host'], domain)

          expiry = row['expiry']
          # Firefox 142+ (schema version 16) started using milliseconds for expiry
          expiry = expiry.to_i / 1000 if schema_version >= 16
          result << cookie_line(row['host'], row['path'], row['isSecure'], expiry, row['name'], row['value'], format: format)
        end
      end
      result
    end
  end
end
