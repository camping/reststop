Gem::Specification.new do |s|
  s.name = %q{reststop}
  s.version = "0.5.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matt Zukowski", "Philippe Monnet"]
  s.date = %q{2010-07-07}
  s.description = %q{A very simple REST client.}
  s.email = ["matt@roughest.net", "techarch@monnet-usa.com"]
  s.homepage = %q{http://wiki.github.com/camping/reststop/}
  s.rubyforge_project = %q{reststop}

  s.platform = Gem::Platform::RUBY 
  s.summary = %q{REST framework for Camping web services}
  s.description = <<-EOF
  s.summary = %q{Convenient RESTfulness for all your Camping needs (i.e. makes it easy to implement RESTful controllers in Camping).}
  EOF

  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.2.0}
  s.has_rdoc = true 
  s.extra_rdoc_files = ["README.rdoc"] 
  

  s.files = ["Rakefile", "setup.rb", "CHANGELOG.txt", "History.txt", "LICENSE.txt", "Manifest.txt", "examples/blog.rb", "lib/reststop.rb", "lib/reststop/version.rb"]
  s.test_files = ["test/test.rb"]
  s.add_dependency(%q<camping>, [">= 2.0.392"])

end
