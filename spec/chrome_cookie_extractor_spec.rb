require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::ChromeCookieExtractor do
  before :each do
    @fake_cookie_db = double("cookie database")
    allow(CookieExtractor::Common).to receive(:with_sqlite).and_call_original
    allow(CookieExtractor::Common).to receive(:with_sqlite).with('filename').and_yield(@fake_cookie_db)
  end

  describe "with a cookie that has a host starting with a dot" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '0',
          'expires_utc' => 12_879_041_490_000_000,
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      expect(@result.size).to eq(1)
    end

    it "should put TRUE in the domain wide field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[1]).to eq("TRUE")
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      expect(cookie_string).to eq(
        ".dallien.net\tTRUE\t/\tFALSE\t1234567890\tNAME\tVALUE")
    end
  end

  describe "with a cookie that has a host not starting with a dot" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host_key' => 'jeff.dallien.net',
          'path' => '/path',
          'secure' => '1',
          'expires_utc' => 12_879_041_490_000_000,
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      expect(@result.size).to eq(1)
    end

    it "should put FALSE in the domain wide field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[1]).to eq("FALSE")
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      expect(cookie_string).to eq(
        "jeff.dallien.net\tFALSE\t/path\tTRUE\t1234567890\tNAME\tVALUE")
    end
  end

  describe "with a cookie that is not marked as secure" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '0',
          'expires_utc' => 12_879_041_490_000_000,
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put FALSE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("FALSE")
    end
  end

  describe "with a cookie that is marked as secure" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '1',
          'expires_utc' => 12_879_041_490_000_000,
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put TRUE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("TRUE")
    end
  end

  describe "with is_secure column" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'is_secure' => '1',
          'expires_utc' => 12_879_041_490_000_000,
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put TRUE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("TRUE")
    end
  end

  describe "with domain filter" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute) do |&block|
        block.call({'host_key' => '.example.com', 'path' => '/', 'is_secure' => '0', 'expires_utc' => 13_443_642_228_769_329, 'name' => 'NAME', 'value' => 'EXAMPLE VALUE'})
        block.call({'host_key' => '.other.test', 'path' => '/', 'is_secure' => '0', 'expires_utc' => 13_429_994_993_015_941, 'name' => 'NAME2', 'value' => 'OTHER VALUE'})
      end
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
    end

    it "returns correct domain" do
      result = @extractor.extract(domain: "example.com", format: :hash)
      expect(result.size).to eq(1)
      expect(result.first[:value]).to eq("EXAMPLE VALUE")
      expect(result.first[:expires]).to eq(1799168628)
    end

    it "returns all when domain is nil" do
      result = @extractor.extract(format: :hash)
      expect(result.size).to eq(2)
      expect(result.map {|r| r[:expires]}).to eq([1799168628, 1785521393])
    end
  end
end
