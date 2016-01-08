TEST_PID = 'druid:dd999dd9999'
TEST_PID_FILENAME = TEST_PID.tr(':', '_')
TEST_APO_OBJECT = 'druid:qv648vd4392' # this is a real APO object in dor-dev that must exist for the tests to pass
PATH = File.expand_path(File.dirname(__FILE__))
TEST_OUTPUT_DIR = File.join(PATH, 'test_data', 'output')
ENV['ROBOT_ENVIRONMENT'] = 'development'

require 'rspec'
require "#{PATH}/../config/boot"
require "#{PATH}/../config/connect_to_dor"

RSpec.configure do |config|
end

def remove_files(dir)
  Dir.foreach(dir) {|f| fn = File.join(dir, f); File.delete(fn) if !File.directory?(fn) && File.basename(fn) != '.empty'}
end

def load_test_object
  pid = ActiveFedora::FixtureLoader.import_to_fedora("#{PATH}/test_data/#{TEST_PID_FILENAME}.xml")
end

def delete_test_object
  Dor::Config.fedora.client["objects/#{TEST_PID}"].delete
end
