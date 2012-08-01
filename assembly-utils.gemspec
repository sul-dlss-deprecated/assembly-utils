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

  s.add_dependency 'csv-mapper'
  s.add_dependency 'dor-services', '>=3.9.0'
  s.add_dependency 'lyber-core'
  s.add_dependency 'net-ssh'
  s.add_dependency 'net-ssh-kerberos'
  s.add_dependency 'net-ssh-gateway'
  s.add_dependency 'druid-tools'

  s.add_development_dependency "rspec", "~> 2.6"
  s.add_development_dependency "lyberteam-devel"
  s.add_development_dependency "lyberteam-gems-devel"
  s.add_development_dependency "lyberteam-capistrano-devel"
  s.add_development_dependency "yard"
  
end