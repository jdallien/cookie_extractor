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
