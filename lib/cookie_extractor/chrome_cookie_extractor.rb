require 'sqlite3'

module CookieExtractor
  class ChromeCookieExtractor

    def initialize(cookie_file)
      @cookie_file = cookie_file
    end

    def extract
      db = SQLite3::Database.new @cookie_file
      db.results_as_hash = true
      @result = []
      db.execute("SELECT * FROM cookies") do |row|
        @result << [ row['host_key'],
          true_false_word(is_domain_wide(row['host_key'])),
          row['path'],
          true_false_word(row['secure']),
          row['expires_utc'],
          row['name'],
          row['value']
        ].join("\t")
      end
      @result
    end

    private

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
  end
end
