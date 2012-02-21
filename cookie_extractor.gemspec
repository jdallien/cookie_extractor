# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "cookie_extractor/version"

Gem::Specification.new do |s|
  s.name        = "cookie_extractor"
  s.version     = CookieExtractor::VERSION
  s.authors     = ["Jeff Dallien"]
  s.email       = ["jeff@dallien.net"]
  s.homepage    = "http://github.com/jdallien/cookie_extractor"
  s.summary     = %q{Create cookies.txt from Firefox cookies}
  s.description = %q{Extract cookies from Firefox sqlite databases into a wget-compatible cookies.txt file.}

  s.rubyforge_project = "cookie_extractor"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_runtime_dependency "sqlite3-ruby"
end
