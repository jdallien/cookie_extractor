require 'digest'
require_relative 'common'
require_relative 'chrome_cookie_decryptor'

module CookieExtractor
  class ChromeCookieExtractor
    include Common

    def initialize(cookie_file, app: nil, secrets: [])
      @cookie_file = cookie_file
      @decryptor = ChromeCookieDecryptor.new(app: app, secrets: secrets)
    end

    def extract(format: :netscape, domain: nil)
      result = []
      with_sqlite(@cookie_file) do |db|
        version = db.get_first_value("SELECT value FROM meta WHERE key = 'version'").to_i
        db.execute("SELECT * FROM cookies") do |row|
          next unless domain.nil? || cookie_applies?(row['host_key'], domain)

          secure = row.key?('is_secure') ? row['is_secure'] : row['secure']
          expires = expires_unix(row['expires_utc'])
          value = decrypt_value(row, version)
          result << cookie_line(row['host_key'], row['path'], secure, expires, row['name'], value, format: format)
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

    def decrypt_value(row, version)
      value = row['value']
      encrypted_value = row['encrypted_value'].to_s
      unless encrypted_value.empty?
        value = @decryptor.decrypt(encrypted_value) do |decrypted_value|
          valid_value?(decrypted_value, version, row['host_key'])
        end
        if version >= 24
          # https://chromium.googlesource.com/chromium/src/+/refs/heads/main/net/extras/sqlite/sqlite_persistent_cookie_store.cc
          # 24+ version prepends SHA256 hash of host_key
          value = value.byteslice(32, value.bytesize - 32)
        end
      end
      value
    end

    def valid_value?(decrypted_value, version, host_key)
      if version >= 24
        decrypted_value.byteslice(0, 32) == Digest::SHA256.digest(host_key)
      else
        decrypted_value.ascii_only?
      end
    end

  end
end
