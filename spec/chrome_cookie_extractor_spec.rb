require File.join(File.dirname(__FILE__), "spec_helper")

def update_value(host_key, value, version = 24)
  version >= 24 ? Digest::SHA256.digest(host_key) + value : value
end

def encrypt_v10(plaintext)
  CookieExtractor::ChromeCookieDecryptor::V10KeyProvider.new.encrypt(plaintext)
end

def encrypt_v11(plaintext, secret)
  CookieExtractor::ChromeCookieDecryptor::SecretKeyProvider.new('chrome').encrypt(plaintext, secret)
end

describe CookieExtractor::ChromeCookieExtractor do

  let(:cookies_sql) do
    <<-SQL
    CREATE TABLE cookies(
      host_key TEXT NOT NULL,
      name TEXT NOT NULL,
      value TEXT NOT NULL,
      encrypted_value BLOB NOT NULL,
      path TEXT NOT NULL,
      expires_utc INTEGER NOT NULL,
      is_secure INTEGER NOT NULL
    );
    SQL
  end

  let(:meta_sql) { "CREATE TABLE meta(key LONGVARCHAR NOT NULL UNIQUE PRIMARY KEY, value LONGVARCHAR);" }

  def cookie_db(rows, version: 24, schema_sql: nil)
    sql = schema_sql || cookies_sql
    create_sqlite_db(rows, table_name: "cookies", table_sql: "#{sql}; #{meta_sql}") do |db|
      db.execute("INSERT INTO meta (key, value) VALUES ('version', ?)", version)
    end
  end

  before :each do
    @fake_cookie_db = double("cookie database", :get_first_value => 23)
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

  describe "with unencrypted cookie" do
    let(:db_path) { cookie_db([["example.org", "NAME", "VALUE", "", "/", 12_879_041_490_000_000, 1]]) }

    it "returns cookie data" do
      expect(described_class.new(db_path).extract(format: :hash)).to eq([
        { domain: "example.org", path: "/", secure: true, expires: 1234567890, name: "NAME", value: "VALUE" }
      ])
    end
  end

  describe "with encrypted cookies" do
    let(:db_path) {
      cookie_db([
        ["example.org", "cookie1", "", encrypt_v10(update_value("example.org", "value1")), "/", 0, 0],
        [".example.com", "cookie2", "", encrypt_v11(update_value(".example.com", "value2"), "test-secret"), "/", 0, 1],
        ["extra.example.com", "cookie3", "", encrypt_v11(update_value("extra.example.com", "value3"), "custom2secret2"), "/", 0, 1]
      ])
    }

    it "decrypts not using SecretService when --secret specified" do
      secret_service = instance_double(CookieExtractor::SecretService)
      expect(secret_service).not_to receive(:secrets)
      allow(CookieExtractor::SecretService).to receive(:new).and_return(secret_service)

      db_path = cookie_db([["diff.example.com", "cookie4", "", encrypt_v11(update_value("diff.example.com", "value4"), "custom 4 secret"), "/", 0, 0]])
      extractor = described_class.new(db_path, secrets: ["custom 4 secret"])

      expect(extractor.extract(format: :hash)).to eq([
        {domain: "diff.example.com", expires: 0, name: "cookie4", path: "/", secure: false, value: "value4"}
      ])
    end

    it "decrypts all cookies" do
      secret_service = instance_double(CookieExtractor::SecretService)
      expect(secret_service).to receive(:secrets).with({ "user" => "Chrome Safe Storage" }).and_return([]).once
      expect(secret_service).to receive(:secrets).with({ "application" => "chrome" }).and_return(["test-secret"]).once
      expect(CookieExtractor::SecretService).to receive(:new).and_return(secret_service).at_least(:once)

      expect(described_class.new(db_path, app: "chrome", secrets: ["custom2secret2"]).extract(format: :hash)).to eq([
        {domain: "example.org", expires: 0, name: "cookie1", path: "/", secure: false, value: "value1"},
        {domain: ".example.com", expires: 0, name: "cookie2", path: "/", secure: true, value: "value2"},
        {domain: "extra.example.com", expires: 0, name: "cookie3", path: "/", secure: true, value: "value3"}
      ])
    end

    it "decrypts old cookies" do
      version = 23
      db_path = cookie_db([["old.example.com", "cookie5", "", encrypt_v10(update_value(nil, "value5", version)), "/", 0, 0]], version: version)

      expect(described_class.new(db_path).extract(format: :hash)).to eq([
        {domain: "old.example.com", expires: 0, name: "cookie5", path: "/", secure: false, value: "value5"}
      ])
    end
  end

end
