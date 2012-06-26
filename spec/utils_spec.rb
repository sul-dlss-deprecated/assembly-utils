describe Assembly::Utils do

  it "compute the correct staging path given a druid" do
    path=Assembly::Utils.get_staging_path('aa000aa0001')
    path.should == 'aa/000/aa/0001'
  end

  it "compute the correct staging path given a druid and a pre-pend path" do
    path=Assembly::Utils.get_staging_path('aa000aa0001','tmp')
    path.should == 'tmp/aa/000/aa/0001'
  end

  
end