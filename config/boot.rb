require 'rubygems'
CERT_DIR = File.join(File.dirname(__FILE__), ".", "certs")

environment  = ENV['ENVIRONMENT'] ||= 'development'
project_root = File.expand_path(File.dirname(__FILE__) + '/..')

# Load config for current environment.
$LOAD_PATH.unshift(project_root + '/lib')

require 'assembly-utils'

Dor::WorkflowService.configure(Dor::Config.workflow.url)
