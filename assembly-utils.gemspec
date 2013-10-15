$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require 'assembly-utils/version'

Gem::Specification.new do |s|
  s.name        = 'assembly-utils'
  s.version     = Assembly::Utils::VERSION
  s.authors     = ["Peter Mangiafico","Monty Hindman"]
  s.email       = ["pmangiafico@stanford.edu"]
  s.homepage    = ""
  s.summary     = %q{Ruby gem of methods usesful for assembly and accessioning.}
  s.description = %q{Contains classes to manipulate DOR objects for assembly and accessioning}

  s.rubyforge_project = 'assembly-utils'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'nokogiri'
  s.add_dependency 'csv-mapper'
  s.add_dependency 'fastercsv'
  s.add_dependency 'druid-tools', ">= 0.2.6"
  
  s.add_dependency 'dor-services', ">= 3.25.1"
  s.add_dependency 'lyber-core'
  s.add_dependency 'dor-workflow-service', '>=1.3.1'
  
  s.add_dependency 'activesupport'
  s.add_dependency 'activeresource'

  s.add_development_dependency "rspec", "~> 2.6"
  s.add_development_dependency "lyberteam-gems-devel", "> 1.0.0"
  s.add_development_dependency "yard"
  
end