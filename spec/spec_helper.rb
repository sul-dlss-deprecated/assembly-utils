TEST_PID='druid:dd999dd9999'
TEST_APO_OBJECT='druid:nt592gh9590'   # this is a real APO object in dor-dev that must exist for the tests to pass
PATH = File.expand_path(File.dirname(__FILE__))
require "#{PATH}/../config/boot"
require "#{PATH}/../config/connect_to_dor"

def load_test_object
  fedora = ActiveFedora::Base.connection_for_pid(0)
  fedora.ingest :pid => TEST_PID, :file =>File.read("#{PATH}/test_data/druid_dd999dd9999.xml")
  Dor.find(TEST_PID).update_index  
end

def delete_test_object
  Dor::Config.fedora.client["objects/#{TEST_PID}"].delete
end



