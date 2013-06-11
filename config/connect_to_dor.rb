environment  = ENV['ENVIRONMENT'] || ENV['ROBOT_ENVIRONMENT'] || ENV['RAILS_ENV'] || 'development'
GEM_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')

# Environment.
ENV_FILE = GEM_ROOT + "/config/environments/#{environment}.rb"
require ENV_FILE

Dor::WorkflowService.configure(Dor::Config.workflow.url)
