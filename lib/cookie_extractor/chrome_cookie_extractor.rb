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
          expires = expires_unix(row['expires_utc'])
          result << cookie_line(row['host_key'], row['path'], secure, expires, row['name'], row['value'], format: format)
        end
      end
      result
    end

    private

    # Chrome stores expiry as microseconds (s/1,000,000) since the Windows epoch (1601-01-01 00:00:00 UTC)
    #
    # https://chromium.googlesource.com/chromium/src/+/refs/heads/main/base/time/time.h
    def expires_unix(expires_utc)
      expires = expires_utc.to_i
      return 0 if expires == 0
      expires / 1_000_000 - 11_644_473_600
    end

  end
end
