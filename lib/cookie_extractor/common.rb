require 'uri'
require 'sqlite3'

module CookieExtractor
  module Common
    private

    def self.with_sqlite(path)
      flags = SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::URI
      db = nil
      begin
        db = SQLite3::Database.new(file_uri(path, :immutable => 0).to_s, flags: flags)
        db.execute("SELECT name FROM sqlite_schema LIMIT 1;")
      rescue SQLite3::BusyException
        db = SQLite3::Database.new(file_uri(path, :immutable => 1).to_s, flags: flags)
      end
      db.results_as_hash = true
      yield db
    ensure
      db&.close
    end

    def with_sqlite(path, &block)
      Common::with_sqlite(path, &block)
    end

    def self.file_uri(path, query)
      path = File.expand_path(path)
      URI::File.build(:path => URI::RFC2396_PARSER.escape(path),
                      :query => query ? URI.encode_www_form(query) : nil)
    end

    def file_binread(path, retries: 5, delay: 0.05)
      attempts = 1
      begin
        File.read(path)
      rescue Errno::ENOENT => error
        attempts += 1
        if attempts <= retries
          sleep(delay)
          retry
        end
        raise error
      end
    end

    def is_domain_wide(hostname)
      hostname[0..0] == "."
    end

    def true_false_word(value)
      if value == "1" || value == 1 || value == true
        "TRUE"
      elsif value == "0" || value == 0 || value == false
        "FALSE"
      else
        raise "Invalid value passed to true_false_word: #{value.inspect}"
      end
    end

    def cookie_applies?(domain, host)
      dot_domain = is_domain_wide(domain)
      dot_host = is_domain_wide(host)

      domain = domain.delete_prefix('.').downcase
      host = host.delete_prefix('.').downcase

      return true if domain == host || dot_domain && host.end_with?(".#{domain}")
      dot_host && domain.end_with?(".#{host}")
    end

    def cookie_line(domain, path, secure, expires, name, value, format: :netscape)
      case format
      when :netscape
        [
          domain,
          true_false_word(is_domain_wide(domain)),
          path,
          true_false_word(secure),
          expires,
          name,
          value
        ].join("\t")
      when :hash, false
        {
          domain: domain,
          path: path,
          secure: true_false_word(secure) == 'TRUE',
          expires: expires.to_i,
          name: name,
          value: value
        }
      else
        raise ArgumentError, "unsupported format: #{format.inspect}"
      end
    end
  end
end
