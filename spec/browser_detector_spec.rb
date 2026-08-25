require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::BrowserDetector, "determining the correct extractor to use" do
  before :each do
    @fake_cookie_db = double("cookie database")
    allow(CookieExtractor::Common).to receive(:with_sqlite).and_call_original
    allow(CookieExtractor::Common).to receive(:with_sqlite).with('filename').and_yield(@fake_cookie_db)
  end

  describe "given a sqlite database with a 'moz_cookies' table" do
    before :each do
      expect(@fake_cookie_db).to receive(:table_info).
        with("moz_cookies").
          and_return(
            { 'name' => 'some_field',
              'type' => "some_type" })
    end

    it "should return a firefox extractor instance" do
      extractor = CookieExtractor::BrowserDetector.new_extractor('filename')
      expect(extractor.instance_of?(CookieExtractor::FirefoxCookieExtractor)).to be true
    end
  end

  describe "given a sqlite database with a 'cookies' table" do
    before :each do
      expect(@fake_cookie_db).to receive(:table_info).
        with("moz_cookies").
          and_return([])
      expect(@fake_cookie_db).to receive(:table_info).
        with("cookies").
          and_return(
            [{ 'name' => 'some_field',
              'type' => "some_type" }])
    end

    it "should return a chrome extractor instance" do
      extractor = CookieExtractor::BrowserDetector.new_extractor('filename')
      expect(extractor.instance_of?(CookieExtractor::ChromeCookieExtractor)).to be true
    end
  end

  describe "with real opened DB" do
    it "reads cookies even when DB is locked" do
      path = create_sqlite_db(
        [["item", "value", ".example.org", "/", 123, 1]],
        table_name: "moz_cookies",
        table_sql: "CREATE TABLE moz_cookies (name TEXT, value TEXT, host TEXT, path TEXT, expiry INTEGER, isSecure INTEGER)"
      )
      db = SQLite3::Database.new(path)
      db.execute("BEGIN EXCLUSIVE")
      begin
        extractor = CookieExtractor::BrowserDetector.new_extractor(path)
        expect(extractor.extract(format: false)).to eq([{domain: ".example.org", expires: 123, name: "item", path: "/", secure: true, value: "value"}])
      ensure
        db.close
      end
    end
  end
end

describe CookieExtractor::BrowserDetector, "guessing the location of the cookie file" do
  describe "when no cookie files are found in the standard locations" do
    before :each do
      allow(Dir).to receive(:glob).and_return([])
    end

    it "should raise NoCookieFileFoundException" do
      expect { CookieExtractor::BrowserDetector.guess }.
        to raise_error(CookieExtractor::NoCookieFileFoundException)
    end
  end

  describe "when multiple cookie files are found in the standard locations" do
    before :each do
      chrome_path = File.expand_path(CookieExtractor::BrowserDetector.cookie_locations("chrome").first)
      firefox_path = File.expand_path(CookieExtractor::BrowserDetector.cookie_locations("firefox").first)
      allow(Dir).to receive(:glob).and_return(
        [chrome_path],
        [],
        [firefox_path],
        []
      )
    end

    describe "and chrome was the most recently used" do
      before :each do
        expect(File).to receive(:mtime).twice.and_return(
          Time.parse("July 2 2013 00:00:00"),
          Time.parse("July 1 2013 00:00:00"))
      end

      it "should build a ChromeCookieExtractor" do
        chrome_path = File.expand_path(CookieExtractor::BrowserDetector.cookie_locations("chrome").first)
        expect(CookieExtractor::BrowserDetector).
          to receive(:browser_extractor).
            once.with(nil, chrome_path)
        CookieExtractor::BrowserDetector.guess
      end
    end
  end 
end
