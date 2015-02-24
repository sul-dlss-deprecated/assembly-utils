require 'spec_helper'

describe Assembly::Utils do
  
  it "should compute the correct staging path given a druid" do
    path=Assembly::Utils.get_staging_path('aa000aa0001')
    expect(path).to eq('aa/000/aa/0001')
  end

  it "should compute the correct staging path given a druid and a pre-pend path" do
    path=Assembly::Utils.get_staging_path('aa000aa0001','/tmp')
    expect(path).to eq('/tmp/aa/000/aa/0001')
  end

  it "should symbolize hash keys correctly" do
    result=Assembly::Utils.symbolize_keys({'foo'=>'bar','ppuff'=>'doofus'}) 
    expect(result).to eq({:foo=>'bar',:ppuff=>'doofus'})
  end

  it "should symbolize hash values correctly" do
    result=Assembly::Utils.values_to_symbols!({'foo'=>'bar','ppuff'=>'doofus'})
    expect(result).to eq({'foo'=>:bar,'ppuff'=>:doofus})
  end
  
  it "should return a blank string if a file is not found to read in" do
    bogus_filename='crap/dude'
    expect(Assembly::Utils.read_file(bogus_filename)).to eq('')
  end

  it "should return a string with the file content if the file is found" do
    progress_filename='spec/test_data/test_log.yaml'
    expect(Assembly::Utils.read_file(progress_filename)).to match(/:pid: druid:bg598tg6338/)
  end
  
  it "should read in a list of completed druids from a progress log file" do
    progress_filename='spec/test_data/test_log.yaml'
    druids=Assembly::Utils.get_druids_from_log(progress_filename)   
    expect(druids).to eq(['druid:bc006dj2846','druid:bg598tg6338'])
  end

  it "should read in a list of failed druids from a progress log file" do
    progress_filename='spec/test_data/test_log.yaml'
    druids=Assembly::Utils.get_druids_from_log(progress_filename,false)   
    expect(druids).to eq(['druid:bh634sp8073'])
  end
  
  it "should read in a YAML configuration file and turn it into a hash" do
    config_filename='spec/test_data/local_dev_revs.yaml'
    config=Assembly::Utils.load_config(config_filename)   
    expect(config['progress_log_file']).to eq('tmp/progress_revs.yaml')
  end

  ###################################################################################
  # NOTE: All the tests below depend on being able to connect successfully to DOR Dev
  describe "dor-only-tests" do

    before(:all) do
      delete_test_object rescue nil
      load_test_object
    end

    after(:all) do
      remove_files(TEST_OUTPUT_DIR)
      delete_test_object
    end
        
    it "should find druids by source ID" do
      expect(Dor::SearchService).to receive(:query_by_id).with('testing-assembly-utils-gem').and_return TEST_PID
      druids=Assembly::Utils.get_druids_by_sourceid(['testing-assembly-utils-gem'])
      expect(druids).to eq([TEST_PID])
    end
  
    it "should replace the datastream of an object" do
      new_content="<xml><tag>stuff</tag></xml>"
      datastream="test"
      druids=[TEST_PID]
      Assembly::Utils.replace_datastreams(druids,datastream,new_content)
      obj = Dor::Item.find(TEST_PID)
      expect(obj.datastreams[datastream].content).to match(/<tag>stuff<\/tag>/)
    end

    it "should search and replace the datastream of an object" do
      find_content="stuff"
      replace_content="new"
      datastream="test"
      druids=[TEST_PID]
      Assembly::Utils.update_datastreams(druids,datastream,find_content,replace_content)
      obj = Dor::Item.find(TEST_PID)
      expect(obj.datastreams[datastream].content).to match(/<tag>new<\/tag>/)
    end
  
    it "should export a PID to FOXML" do
      expect(File.exists?(File.join(TEST_OUTPUT_DIR,"#{TEST_PID_FILENAME}.foxml.xml"))).to be false
      Dir.mkdir(TEST_OUTPUT_DIR) unless Dir.exists?(TEST_OUTPUT_DIR)
      Assembly::Utils.export_objects(TEST_PID,TEST_OUTPUT_DIR)
      expect(File.exists?(File.join(TEST_OUTPUT_DIR,"#{TEST_PID_FILENAME}.foxml.xml"))).to be true
    end
  
    it "should return nil when the workflow state is not found in an object" do
      expect(Assembly::Utils.get_workflow_status(TEST_PID,'assemblyWF','jp2-create')).to be_nil
    end
  
    it "should indicate if the specified workflow is defined in an APO object" do
      Assembly::Utils.apo_workflow_defined?(TEST_APO_OBJECT,'accessionWF').should be true
      Assembly::Utils.apo_workflow_defined?(TEST_APO_OBJECT,'accessioning').should be true
    end

    it "should indicate if the specified workflow is not defined in an APO object" do
      Assembly::Utils.apo_workflow_defined?(TEST_APO_OBJECT,'crapsticks').should be false
    end

    it "should indicate if the specified object is not an APO" do
      expect{Assembly::Utils.apo_workflow_defined?(TEST_PID,'crapsticks')}.to raise_error 
    end  
  
  end
  
end