$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'assembly-utils/version'

Gem::Specification.new do |s|
  s.name        = 'assembly-utils'
  s.version     = Assembly::Utils::VERSION
  s.authors     = ['Peter Mangiafico', 'Monty Hindman']
  s.email       = ['pmangiafico@stanford.edu']
  s.homepage    = ''
  s.summary     = 'Ruby gem of methods usesful for assembly and accessioning.'
  s.description = 'Contains classes to manipulate DOR objects for assembly and accessioning'

  s.rubyforge_project = 'assembly-utils'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.bindir        = 'exe'
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'nokogiri'
  s.add_dependency 'druid-tools', '>= 0.2.6'

  s.add_dependency 'dor-services', '< 7.0', '>= 5.5'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'yard'

end
