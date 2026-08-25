require_relative 'common'

module CookieExtractor
  class ChromeCookieExtractor
    include Common

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract(format: :netscape, domain: nil)
      result = []
      with_sqlite(@cookie_file) do |db|
        db.execute("SELECT * FROM cookies") do |row|
          next unless domain.nil? || cookie_applies?(row['host_key'], domain)

          secure = row.key?('is_secure') ? row['is_secure'] : row['secure']
          result << cookie_line(row['host_key'], row['path'], secure, row['expires_utc'], row['name'], row['value'], format: format)
        end
      end
      result
    end
  end
end
