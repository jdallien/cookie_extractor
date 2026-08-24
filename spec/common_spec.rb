require_relative "spec_helper"

describe CookieExtractor::Common do
  let(:common) do
    Class.new { include CookieExtractor::Common }.new
  end

  describe "#cookie_applies?" do
    it "matches domain" do
      expect(common.send(:cookie_applies?, "example.com", "example.com")).to be true
      expect(common.send(:cookie_applies?, ".other.test", "example.com")).to be false
    end

    it "matches dot domain" do
      expect(common.send(:cookie_applies?, ".example.com", "example.com")).to be true
    end

    it "matches subdomain" do
      expect(common.send(:cookie_applies?, ".example.com", "www.example.com")).to be true
      expect(common.send(:cookie_applies?, ".example.com", "api.example.com")).to be true
    end

    it "does not match host-only cookie to subdomain" do
      expect(common.send(:cookie_applies?, "example.com", "www.example.com")).to be false
      expect(common.send(:cookie_applies?, "example.com", "api.example.com")).to be false
    end

    it "does not match subdomain cookie" do
      expect(common.send(:cookie_applies?, "www.example.com", "example.com")).to be false
    end

    it "is case-insensitive" do
      expect(common.send(:cookie_applies?, ".Example.COM", "example.com")).to be true
      expect(common.send(:cookie_applies?, ".example.com", "EXAMPLE.COM")).to be true
    end

    it "handles host filter" do
      expect(common.send(:cookie_applies?, "sub.example.com", ".example.com")).to be true
      expect(common.send(:cookie_applies?, "other.com", ".example.com")).to be false
    end
  end

  describe "#cookie_line" do
    it "builds netscape format" do
      line = common.send(:cookie_line, ".dallien.net", "/", "0", "1234567890", "NAME", "VALUE", format: :netscape)
      expect(line).to eq(".dallien.net\tTRUE\t/\tFALSE\t1234567890\tNAME\tVALUE")
    end

    it "builds hash format with format: :hash" do
      h = common.send(:cookie_line, ".dallien.net", "/", "0", "1234567890", "NAME", "VALUE", format: :hash)
      expect(h).to eq(domain: ".dallien.net", path: "/", secure: false, expires: 1234567890, name: "NAME", value: "VALUE")
    end

    it "builds hash format with format: false" do
      h = common.send(:cookie_line, ".dallien.net", "/", 1, "1234567890", "NAME", "VALUE", format: false)
      expect(h[:secure]).to eq(true)
      expect(h[:expires]).to eq(1234567890)
    end
  end
end
