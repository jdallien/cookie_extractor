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

  describe ".file_uri" do
    it "builds file uri with immutable" do
      uri = CookieExtractor::Common.file_uri("/tmp/foo + bar.sqlite", immutable: 1)
      expect(uri.scheme).to eq("file")
      expect(uri.path).to eq("/tmp/foo%20+%20bar.sqlite")
      expect(uri.query).to eq("immutable=1")
      expect(uri.to_s).to eq("file:///tmp/foo%20+%20bar.sqlite?immutable=1")
    end

    it "builds file uri without query when nil" do
      uri = CookieExtractor::Common.file_uri("/tmp/foo.sqlite", nil)
      expect(uri.query).to be_nil
    end

    it "expands relative path to absolute" do
      relative = "relative_test.sqlite"
      path = File.expand_path(relative)
      uri = CookieExtractor::Common.file_uri(relative, immutable: 1)
      expect(uri.path).to eq(URI::RFC2396_PARSER.escape(path))
    end
  end

  describe ".with_sqlite" do
    let(:table_sql) { "CREATE TABLE test (id INTEGER, item TEXT)" }
    let(:db_file) { create_sqlite_db([[1, "item value"]], table_name: "test", table_sql: table_sql) }

    it "should open sqlite db" do
      allow(SQLite3::Database).to receive(:new).and_call_original
      CookieExtractor::Common.with_sqlite(db_file) do |db|
        expect(db).to be_a(SQLite3::Database)
        row = db.execute("SELECT * FROM test").first
        expect(row).to be_a(Hash)
        expect(row["item"]).to eq("item value")
        expect { db.execute("INSERT INTO test VALUES (2, 'nope')") }.to raise_error(SQLite3::ReadOnlyException)
      end
      expected_file = /^file:\/\/\/.+\.sqlite\?immutable=0$/
      expected_options = { flags: SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::URI }
      expect(SQLite3::Database).to have_received(:new).with(expected_file, expected_options)
    end

    it "retries with immutable=1 when BusyException" do
      path = db_file
      db = SQLite3::Database.new(path)
      db.execute("BEGIN EXCLUSIVE")
      allow(SQLite3::Database).to receive(:new).and_call_original
      begin
        CookieExtractor::Common.with_sqlite(path) do |db|
          expect(db).to be_a(SQLite3::Database)
          row = db.execute("SELECT * FROM test").first
          expect(row).to be_a(Hash)
          expect(row["item"]).to eq("item value")
          expect { db.execute("INSERT INTO test VALUES (2, 'nope')") }.to raise_error(SQLite3::ReadOnlyException)
        end
      ensure
        db.close
      end
      expect(SQLite3::Database).to have_received(:new).with(%r{immutable=0}, flags: SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::URI)
      expect(SQLite3::Database).to have_received(:new).with(%r{immutable=1}, flags: SQLite3::Constants::Open::READONLY | SQLite3::Constants::Open::URI)
    end

    it "should close the db when finished" do
      allow(SQLite3::Database).to receive(:new).and_wrap_original do |original_method, *args|
        db = original_method.call(*args)
        expect(db).to receive(:close).and_call_original
        db
      end
      expect { CookieExtractor::Common.with_sqlite(db_file) { raise "err" } }.to raise_error("err")
    end

    it "reads db with relative path" do
      path = db_file
      relative = File.basename(path)
      Dir.chdir(File.dirname(path)) do
        result = nil
        CookieExtractor::Common.with_sqlite(relative) do |db|
          result = db.execute("SELECT * FROM test").first
        end
        expect(result["item"]).to eq("item value")
      end
    end
  end

  describe "#file_binread" do
    it "retries on ENOENT and succeeds" do
      attempts = 0
      allow(File).to receive(:read) do |_path|
        attempts += 1
        raise Errno::ENOENT, "no file" if attempts < 3
        "content"
      end
      allow(Kernel).to receive(:sleep)
      result = common.send(:file_binread, "/tmp/missing", retries: 5, delay: 0.01)
      expect(result).to eq("content")
      expect(attempts).to eq(3)
    end

    it "raises after retries exhausted" do
      allow(File).to receive(:read).and_raise(Errno::ENOENT, "no file")
      allow(Kernel).to receive(:sleep)
      expect { common.send(:file_binread, "/tmp/missing", retries: 2, delay: 0.01) }.to raise_error(Errno::ENOENT)
    end

    it "does not retry on other errors" do
      allow(File).to receive(:read).and_raise(Errno::EACCES, "permission")
      expect(Kernel).not_to receive(:sleep)
      expect { common.send(:file_binread, "/tmp/test") }.to raise_error(Errno::EACCES)
    end
  end
end
