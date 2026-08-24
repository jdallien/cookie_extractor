require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::FirefoxCookieExtractor do
  before :each do
    @fake_cookie_db = double("cookie database",
      :results_as_hash= => true,
      :close => true)
    expect(SQLite3::Database).to receive(:new).
      with('filename').
        and_return(@fake_cookie_db)
  end

  describe "opening and closing a sqlite db" do
    before :each do
      expect(@fake_cookie_db).to receive(:execute).and_yield(
        {'host' => '.dallien.net',
          'path' => '/',
          'isSecure' => '0',
          'expiry' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::FirefoxCookieExtractor.new('filename')
    end

    it "should close the db when finished" do
      expect(@fake_cookie_db).to receive(:close)
      @extractor.extract
    end
  end

  describe "with a cookie that has a host starting with a dot" do
    before :each do
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
end
