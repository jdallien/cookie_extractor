require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::BrowserDetector, "determining the correct extractor to use" do
  before :each do
    @fake_cookie_db = double("cookie database", :close => true)
    SQLite3::Database.should_receive(:new).
      with('filename').
        and_return(@fake_cookie_db)
  end

  describe "given a sqlite database with a 'moz_cookies' table" do
    before :each do
      @fake_cookie_db.should_receive(:table_info).
        with("moz_cookies").
          and_return(
            { 'name' => 'some_field',
              'type' => "some_type" })
    end

    it "should return a firefox extractor instance" do
      extractor = CookieExtractor::BrowserDetector.new_extractor('filename')
      extractor.instance_of?(CookieExtractor::FirefoxCookieExtractor).should be_true
    end
  end

  describe "given a sqlite database with a 'cookies' table" do
    before :each do
      @fake_cookie_db.should_receive(:table_info).
        with("moz_cookies").
          and_return([])
      @fake_cookie_db.should_receive(:table_info).
        with("cookies").
          and_return(
            [{ 'name' => 'some_field',
              'type' => "some_type" }])
    end

    it "should return a chrome extractor instance" do
      extractor = CookieExtractor::BrowserDetector.new_extractor('filename')
      extractor.instance_of?(CookieExtractor::ChromeCookieExtractor).should be_true
    end
  end
end

describe CookieExtractor::BrowserDetector, "guessing the location of the cookie file" do
  describe "when no cookie files are found in the standard locations" do
    before :each do
      Dir.stub!(:glob).and_return([])
    end

    it "should raise NoCookieFileFoundException" do
      lambda { CookieExtractor::BrowserDetector.guess }.
        should raise_error(CookieExtractor::NoCookieFileFoundException)
    end
  end

  describe "when multiple cookie files are found in the standard locations" do
    before :each do
      cookie_locations = CookieExtractor::BrowserDetector::COOKIE_LOCATIONS
      Dir.stub!(:glob).and_return([cookie_locations['chrome']],
                                  [],
                                  [cookie_locations['firefox']])
    end

    describe "and chrome was the most recently used" do
      before :each do
        File.should_receive(:mtime).twice.and_return(
          Time.parse("July 2 2013 00:00:00"),
          Time.parse("July 1 2013 00:00:00"))
      end

      it "should build a ChromeCookieExtractor" do
        CookieExtractor::BrowserDetector.
          should_receive(:browser_extractor).
            once.with("chrome")
        CookieExtractor::BrowserDetector.guess
      end
    end
  end 
end
