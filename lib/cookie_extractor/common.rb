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
  end
end
