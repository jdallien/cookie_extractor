require File.join(File.dirname(__FILE__), "spec_helper")

describe CookieExtractor::ChromeCookieExtractor do
  before :each do
    @fake_cookie_db = double("cookie database",
      :results_as_hash= => true,
      :close => true)
    SQLite3::Database.should_receive(:new).
      with('filename').
        and_return(@fake_cookie_db)
  end

  describe "opening and closing a sqlite db" do
    before :each do
      @fake_cookie_db.should_receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '0',
          'expires_utc' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
    end

    it "should close the db when finished" do
      @fake_cookie_db.should_receive(:close)
      @extractor.extract
    end
  end

  describe "with a cookie that has a host starting with a dot" do
    before :each do
      @fake_cookie_db.should_receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '0',
          'expires_utc' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      @result.size.should == 1
    end

    it "should put TRUE in the domain wide field" do
      cookie_string = @result.first
      cookie_string.split("\t")[1].should == "TRUE"
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      cookie_string.should ==
        ".dallien.net\tTRUE\t/\tFALSE\t1234567890\tNAME\tVALUE"
    end
  end

  describe "with a cookie that has a host not starting with a dot" do
    before :each do
      @fake_cookie_db.should_receive(:execute).and_yield(
        { 'host_key' => 'jeff.dallien.net',
          'path' => '/path',
          'secure' => '1',
          'expires_utc' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should return one cookie string" do
      @result.size.should == 1
    end

    it "should put FALSE in the domain wide field" do
      cookie_string = @result.first
      cookie_string.split("\t")[1].should == "FALSE"
    end

    it "should build the correct cookie string" do
      cookie_string = @result.first
      cookie_string.should ==
        "jeff.dallien.net\tFALSE\t/path\tTRUE\t1234567890\tNAME\tVALUE"
    end
  end

  describe "with a cookie that is not marked as secure" do
    before :each do
      @fake_cookie_db.should_receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '0',
          'expires_utc' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put FALSE in the secure field" do
      cookie_string = @result.first
      cookie_string.split("\t")[3].should == "FALSE"
    end
  end

  describe "with a cookie that is marked as secure" do
    before :each do
      @fake_cookie_db.should_receive(:execute).and_yield(
        { 'host_key' => '.dallien.net',
          'path' => '/',
          'secure' => '1',
          'expires_utc' => '1234567890',
          'name' => 'NAME',
          'value' => 'VALUE'})
      @extractor = CookieExtractor::ChromeCookieExtractor.new('filename')
      @result = @extractor.extract
    end

    it "should put TRUE in the secure field" do
      cookie_string = @result.first
      cookie_string.split("\t")[3].should == "TRUE"
    end
  end
end
