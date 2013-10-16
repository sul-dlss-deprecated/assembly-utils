require "bundler/gem_tasks"

require 'dlss/rake/dlss_release'
Dlss::Release.new

require 'rspec/core/rake_task'

desc "Run specs"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec