require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::FirefoxCookieExtractor do
  before :each do
    @fake_cookie_db = double("cookie database")
    allow(CookieExtractor::Common).to receive(:with_sqlite).and_call_original
    allow(CookieExtractor::Common).to receive(:with_sqlite).with('filename').and_yield(@fake_cookie_db)
  end

  describe "with a cookie that has a host starting with a dot" do
    before :each do
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(15)
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        {'host' => '.dallien.net',
          'path' => '/',
          'isSecure' => '0',
          'expiry' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      expect(@result.size).to eq(1)
    end

    it "should put TRUE in the domain wide field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[1]).to eq("TRUE")
    end

    it "should put FALSE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("FALSE")
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      expect(cookie_string).to eq(
        ".dallien.net\tTRUE\t/\tFALSE\t1234567890\tNAME\tVALUE")
    end
  end

  describe "with a cookie that has a host not starting with a dot" do
    before :each do
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(15)
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        { 'host' => 'jeff.dallien.net',
          'path' => '/path',
          'isSecure' => '1',
          'expiry' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      expect(@result.size).to eq(1)
    end

    it "should put FALSE in the domain wide field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[1]).to eq("FALSE")
    end

    it "should put TRUE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("TRUE")
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      expect(cookie_string).to eq(
        "jeff.dallien.net\tFALSE\t/path\tTRUE\t1234567890\tNAME\tVALUE")
    end
  end

  describe "with a cookie that is not marked as secure" do
    before :each do
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(15)
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        {'host' => '.dallien.net',
          'path' => '/',
          'isSecure' => '0',
          'expiry' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put FALSE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("FALSE")
    end
  end

  describe "with a cookie that is marked as secure" do
    before :each do
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(15)
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        {'host' => '.dallien.net',
          'path' => '/',
          'isSecure' => '1',
          'expiry' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put TRUE in the secure field" do
      cookie_string = @result.first
      expect(cookie_string.split("\t")[3]).to eq("TRUE")
    end
  end

  describe "with domain filter" do
    before :each do
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(16)
      expect(@fake_cookie_db).to receive(:execute) do |&block|
        block.call({'host' => '.example.com', 'path' => '/', 'isSecure' => '0', 'expiry' => '1787601234000', 'name' => 'NAME', 'value' => 'EXAMPLE VALUE'})
        block.call({'host' => '.other.test', 'path' => '/', 'isSecure' => '0', 'expiry' => '1787601234000', 'name' => 'NAME2', 'value' => 'OTHER VALUE'})
      end
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
    end

    it "returns correct domain" do
      result = @extractor.extract(domain: "example.com", format: :hash)
      expect(result.size).to eq(1)
      expect(result.first[:value]).to eq("EXAMPLE VALUE")
      expect(result.first[:expires]).to eq(1787601234)
    end

    it "returns all when domain is nil" do
      result = @extractor.extract(format: :hash)
      expect(result.size).to eq(2)
    end
  end

  describe "with session cookies" do
    def build_recovery_data(cookies)
      json = JSON.generate("cookies" => cookies)
      compressed = LZ4.block_encode(json)
      header = "mozLz40\0"
      size = [json.bytesize].pack("V")
      header + size + compressed
    end

    let (:recovery_path) { File.dirname('filename') + '/sessionstore-backups/recovery.jsonlz4' }
    let (:recovery_data) {
      build_recovery_data([
        {"host" => ".example.com", "path" => "/", "secure" => true, "name" => "SESSION", "value" => "SESSION VALUE"},
        {"host" => "another.example.org", "path" => "/", "secure" => true, "name" => "SESSION2", "value" => "SESSION2 VALUE"}
      ])
    }

    before :each do
      allow(CookieExtractor::Common).to receive(:with_sqlite).with('filename').and_yield(@fake_cookie_db)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:read).and_call_original
      expect(@fake_cookie_db).to receive(:get_first_value).and_return(16)
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        {'host' => '.dallien.net', 'path' => '/', 'isSecure' => '0', 'expiry' => '1234567890', 'name' => 'PERSISTENT', 'value' => 'PERSISTENT VALUE'}
      )
    end

    it "returns persistent + session cookies" do
      allow(File).to receive(:exist?).with(recovery_path).and_return(true)
      allow(File).to receive(:read).with(recovery_path).and_return(recovery_data)
      extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      result = extractor.extract(format: :hash)
      expect(result.size).to eq(3)
      expect(result.first).to eq({domain: ".dallien.net", expires: 1234567, name: "PERSISTENT", path: "/", secure: false, value: "PERSISTENT VALUE"})
      expect(result.last).to eq({domain: "another.example.org", expires: 0, name: "SESSION2", path: "/", secure: true, value: "SESSION2 VALUE"})
    end

    it "filters session cookies by domain" do
      allow(File).to receive(:exist?).with(recovery_path).and_return(true)
      allow(File).to receive(:read).with(recovery_path).and_return(recovery_data)
      extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      result = extractor.extract(domain: ".example.org", format: :hash)
      expect(result).to eq([{domain: "another.example.org", expires: 0, name: "SESSION2", path: "/", secure: true, value: "SESSION2 VALUE"}])
    end

    it "returns only persistent when recovery file missing" do
      allow(File).to receive(:exist?).with(recovery_path).and_return(false)
      expect(File).not_to receive(:read).with(recovery_path)

      extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
      result = extractor.extract(format: :hash)
      expect(result.size).to eq(1)
      expect(result.first[:value]).to eq("PERSISTENT VALUE")
    end
  end
end
