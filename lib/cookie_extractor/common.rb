module CookieExtractor
  module Common
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
