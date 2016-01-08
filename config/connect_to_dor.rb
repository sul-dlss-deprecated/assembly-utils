environment = ENV['ENVIRONMENT'] ||= 'development'
GEM_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')

# Environment.
env_file = GEM_ROOT + "/config/environments/#{environment}.rb"
require env_file if File.file?(env_file)
