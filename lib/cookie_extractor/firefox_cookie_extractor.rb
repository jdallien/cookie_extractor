require 'json'
require 'extlz4'

require_relative 'common'

module CookieExtractor
  class FirefoxCookieExtractor
    include Common

    def initialize(cookie_file, app: nil, secrets: [])
      @cookie_file = cookie_file
      @recovery_file = File.dirname(@cookie_file) + '/sessionstore-backups/recovery.jsonlz4'
      @recovery_file = nil unless File.exist?(@recovery_file)
    end

    def extract(format: :netscape, domain: nil)
      persistent_cookies(format: format, domain: domain) + session_cookies(format: format, domain: domain)
    end

    def persistent_cookies(format:, domain:)
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

    def session_cookies(format:, domain:)
      return [] unless @recovery_file
      data = file_binread(@recovery_file)
      return [] if data.bytesize <= 12 || data.byteslice(0, 8) != "mozLz40\0"

      uncompressed_size = data.byteslice(8, 4).unpack1("V")
      compressed = data.byteslice(12, data.bytesize - 12)
      max_dest_size = [uncompressed_size, 100 * 1024 * 1024].min
      json = LZ4.block_decode(compressed, max_dest_size)
      recovery = JSON.parse(json)
      recovery['cookies'].to_a.filter_map do |cookie|
        next unless domain.nil? || cookie_applies?(cookie['host'], domain)
        cookie_line(cookie['host'], cookie['path'], !!cookie['secure'], 0, cookie['name'], cookie['value'], format: format)
      end
    end

  end
end
