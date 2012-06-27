describe Assembly::Utils do

  it "should compute the correct staging path given a druid" do
    path=Assembly::Utils.get_staging_path('aa000aa0001')
    path.should == 'aa/000/aa/0001'
  end

  it "should compute the correct staging path given a druid and a pre-pend path" do
    path=Assembly::Utils.get_staging_path('aa000aa0001','/tmp')
    path.should == '/tmp/aa/000/aa/0001'
  end

  it "should symbolize hash keys correctly" do
    result=Assembly::Utils.symbolize_keys({'foo'=>'bar','ppuff'=>'doofus'}) 
    result.should == {:foo=>'bar',:ppuff=>'doofus'}
  end

  it "should symbolize hash values correctly" do
    result=Assembly::Utils.values_to_symbols!({'foo'=>'bar','ppuff'=>'doofus'})
    result.should == {'foo'=>:bar,'ppuff'=>:doofus}
  end
  
  it "should return a blank string if a file is not found to read in" do
    bogus_filename='crap/dude'
    Assembly::Utils.read_file(bogus_filename).should == ''
  end

  it "should return a string with the file content if the file is found" do
    progress_filename='spec/test_data/test_log.yaml'
    Assembly::Utils.read_file(progress_filename).should =~ /:pid: druid:bg598tg6338/
  end
  
  it "should read in a list of completed druids from a progress log file" do
    progress_filename='spec/test_data/test_log.yaml'
    druids=Assembly::Utils.get_druids_from_log(progress_filename)   
    druids.should == ['druid:bc006dj2846','druid:bg598tg6338']
  end

  it "should read in a list of failed druids from a progress log file" do
    progress_filename='spec/test_data/test_log.yaml'
    druids=Assembly::Utils.get_druids_from_log(progress_filename,false)   
    druids.should == ['druid:bh634sp8073']
  end
  
  it "should read in a YAML configuration file and turn it into a hash" do
    config_filename='spec/test_data/local_dev_revs.yaml'
    config=Assembly::Utils.load_config(config_filename)   
    config['progress_log_file'].should == 'tmp/progress_revs.yaml'
  end
  
  it "should connect to DOR dev and find druids by source ID" do
    # this test depends on a specific object being in dor DEV
    druids=Assembly::Utils.get_druids_by_sourceid(['REVS:reg-app-1'])
    druids.should == ['druid:zg352kf6612']
  end
end