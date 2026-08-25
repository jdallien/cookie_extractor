require 'time'
require 'tmpdir'
require 'sqlite3'

require File.expand_path(File.join(File.dirname(__FILE__), "..", "lib", "cookie_extractor"))

module Helpers
  def create_sqlite_db(rows, table_name:, table_sql:)
    @files ||= []
    path = Dir::Tmpname.create(["cookie_extractor_testdb", ".sqlite"]) {}
    @files << path
    db = SQLite3::Database.new(path)
    table_sql.split(";").map(&:strip).reject(&:empty?).each do |statement|
      db.execute(statement)
    end
    rows.each do |row|
      placeholders = (["?"] * row.size).join(", ")
      db.execute("INSERT INTO #{table_name} VALUES (#{placeholders})", row)
    end
    path
  ensure
    db&.close
  end
end

RSpec.configure do |config|
  config.include Helpers

  config.after(:each) do
    @files&.each do |path|
      File.delete(path) if File.exist?(path)
    end
  end
end
