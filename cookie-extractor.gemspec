# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cookie-extractor/version"

Gem::Specification.new do |s|
  s.name        = "cookie-extractor"
  s.version     = CookieExtractor::VERSION
  s.authors     = ["Jeff Dallien"]
  s.email       = ["jeff@dallien.net"]
  s.homepage    = "http://jeff.dallien.net/"
  s.summary     = %q{Create cookies.txt from Firefox or Chrome cookies}
  s.description = %q{Extract cookies from Firefox or Chrome sqlite databases into a wget-compatible cookies.txt file.}

  s.rubyforge_project = "cookie-extractor"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_runtime_dependency "sqlite3-ruby"
end
