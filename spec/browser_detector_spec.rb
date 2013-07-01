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
      Dir.stub!(:glob).and_return(CookieExtractor::BrowserDetector.cookie_locations.values)
    end

    it "should return a ChromeCookieExtractor or FirefoxCookieExtractor" do
      lambda { CookieExtractor::BrowserDetector.guess }.
        should be_kind_of(CookieExtractor::Common)
    end
  end
end
