require 'net/ssh'
require 'csv'
require 'csv-mapper'
require 'druid-tools'

begin
require 'net/ssh/kerberos'
rescue LoadError
end

module Assembly


  # The Utils class contains methods to help with accessioning and assembly
  class Utils

    WFS  = Dor::WorkflowService
    REPO = 'dor'
    
    # Get the staging directory tree given a druid, and optionally prepend a basepath.
    # Deprecated and should not be needed anymore.
    #
    # @param [String] pid druid pid (e.g. 'aa000aa0001')
    # @param [String] base_path optional base path to prepend to druid path
    #
    # @return [string] path to material that is being staged, with optional prepended base path
    #
    # Example:
    #   puts Assembly::Utils.get_staging_path('aa000aa0001','tmp')
    #   > "tmp/aa/000/aa/0001"
    def self.get_staging_path(pid,base_path=nil)
      d=DruidTools::Druid.new(pid,base_path)
      path=File.dirname(d.path)
      return path
    end

    # Insert the specified workflow into the specified object.
    #
    # @param [String] pid druid pid (e.g. 'aa000aa0001')
    # @param [String] workflow name (e.g. 'accessionWF')
    # @param [String] repository name (e.g. 'dor') -- optional, defaults to dor 
    #
    # @return [boolean] indicates success of web service call
    #
    # Example:
    #   puts Assembly::Utils.insert_workflow('druid:aa000aa0001','accessionWF')
    #   > true
    def self.insert_workflow(pid,workflow,repo='dor')
      url   = "#{Dor::Config.dor.service_root}/objects/#{pid}/apo_workflows/#{workflow}"
      result = RestClient.post url, {}
      return ([200,201,202,204].include?(result.code) && result)
    end
    
    # Claim a specific druid as already used to be sure it won't get used again.
    # Not needed for normal purposes, only if you manually register something in Fedora Admin outside of DOR services gem.
    #
    # @param [String] pid druid pid (e.g. 'aa000aa0001')
    #
    # @return [boolean] indicates success of web service call
    #
    # Example:
    #   puts Assembly::Utils.claim_druid('aa000aa0001')
    #   > true
    def self.claim_druid(pid)
      sc    = Dor::Config.suri
      url   = "#{sc.url}/suri2/namespaces/#{sc.id_namespace}"
      rcr   = RestClient::Resource.new(url, :user => sc.user, :password => sc.pass)
      resp  = rcr["identifiers/#{pid}"].put('')
      return resp.code == "204"
    end
    
    # Force a full re-index of the supplied druid in solr and fedora.
    #
    # @param [String] druid druid (e.g. 'druid:aa000aa0001')
    #
    # Example:
    #   puts Assembly::Utils.reindex('druid:aa000aa0001')
    def self.reindex(druid)
      obj = Dor.load_instance druid
      solr_doc = obj.to_solr
      Dor::SearchService.solr.add(solr_doc, :add_attributes => {:commitWithin => 1000}) unless obj.nil? 
      Dor.find(pid).update_index
    end
    
    # Export one or more objects given a single or array of pids, with output to the specified directory as FOXML files
    #
    # @param [Array] pids - an array of pids to export (can also pass a single pid as a string)
    # @param [String] output_dir - the full path to output the foxml files
    #
    # Example:
    #  Assembly::Utils.export_objects(['druid:aa000aa0001','druid:bb000bb0001'],'/tmp')
    def self.export_objects(pids,output_dir)
      pids=[pids] if pids.class==String
      pids.each {|pid| ActiveFedora::FixtureExporter.export_to_path(pid, output_dir)}  
    end

    # Import all of the FOXML files in the specified directory into Fedora
    #
    # @param [String] source_dir - the full path to import the foxml files
    #
    # Example:
    #  Assembly::Utils.import_objects('/tmp')
    def self.import_objects(source_dir)
      Dir.chdir(source_dir)
      files=Dir.glob('*.foxml.xml')
      files.each do |file|
        pid = ActiveFedora::FixtureLoader.import_to_fedora(File.join(source_dir,file))
        ActiveFedora::FixtureLoader.index(pid)
      end
    end
    
    # Get a list of druids that match the given array of source IDs.  
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [String] source_ids array of source ids to lookup
    #
    # @return [array] druids
    # Example:
    #
    #   puts Assembly::Utils.get_druids_by_sourceid(['revs-01','revs-02'])
    #   > ['druid:aa000aa0001','druid:aa000aa0002']
    def self.get_druids_by_sourceid(source_ids)
      druids=[]
      source_ids.each {|sid| druids  <<  Dor::SearchService.query_by_id(sid)}
      druids.flatten
    end
 
    # Show the workflow status of specific steps in assembly and/or accession workflows for the provided druids.  
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [Hash] params parameters specified as a hash, using symbols for options:
    #   * :druids => array of druids to get workflow status for
    #   * :workflows => an optional array of workflow names as symbols, options are :assembly and :accession; defaults to :assembly
    #   * :filename =>  optional filename if you want to send output to a CSV
    #
    # @return [string] comma delimited output or CSV file
    #
    # Example:
    #   Assembly::Utils.workflow_status(:druids=>['druid:aa000aa0001','druid:aa000aa0002'],:workflows=>[:assembly,:accession],:filename=>'output.csv')
    def self.workflow_status(params={})

      druids=params[:druids] || []
      workflows=params[:workflows] || [:assembly]
      filename=params[:filename] || ''

      accession_steps = %w(content-metadata	descriptive-metadata rights-metadata remediate-object shelve publish)
      assembly_steps = %w(jp2-create checksum-compute exif-collect accessioning-initiate)

      puts "Generating report"

      csv = CSV.open(filename, "w") if filename != ''
      
      header=["druid"]
      header << assembly_steps if workflows.include?(:assembly)
      header << accession_steps if workflows.include?(:accession)
      csv << header.flatten if filename != ''
      puts header.join(',')            
    
      druids.each do |druid|
        output=[druid]
        assembly_steps.each {|step| output << self.get_workflow_status(druid,'assemblyWF',step)} if workflows.include?(:assembly) 
        accession_steps.each {|step| output << self.get_workflow_status(druid,'accessionWF',step)} if workflows.include?(:accession) 
        csv << output if filename != ''
        puts output.join(',')
      end
      
      if filename != ''
        csv.close   
        puts "Report generated in #{filename}"
      end

    end

    # Show the workflow status of a specific step in a specific workflow for the provided druid.  
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [string] druid a druid string
    # @param [string] workflow name of workflow
    # @param [string] step name of step
    #
    # @return [string] workflow step status, returns nil if no workflow found
    #
    # Example:
    #   puts Assembly::Utils.get_workflow_status('druid:aa000aa0001','assemblyWF','jp2-create')
    #   > "completed"
    def self.get_workflow_status(druid,workflow,step)
      Dor::WorkflowService.get_workflow_status('dor', druid, workflow, step)  
    end
    
     # Cleanup a list of objects and associated files given a list of druids.  WARNING: VERY DESTRUCTIVE. 
     # This method only works when this gem is used in a project that is configured to connect to DOR
     #
     # @param [Hash] params parameters specified as a hash, using symbols for options:
     #   * :druids => array of druids to cleanup
     #   * :steps => an array of steps, specified as symbols, indicating steps to be run, options are:
     #                :stacks=This will remove all files from the stacks that were shelved for the objects
     #                :dor=This will delete objects from Fedora
     #                :stage=This will delete the staged content in the assembly workspace
     #                :symlinks=This will remove the symlink from the dor workspace
     #                :workflows=This will remove the assemblyWF and accessoiningWF workflows for this object
     #   * :dry_run =>  do not actually clean up (defaults to false)
     #
     # Example:
     #   Assembly::Utils.cleanup(:druids=>['druid:aa000aa0001','druid:aa000aa0002'],:steps=>[:stacks,:dor,:stage,:symlinks,:workflows])
     def self.cleanup(params={})
       
       druids=params[:druids] || []
       steps=params[:steps] || []
       dry_run=params[:dry_run] || false
       
       allowed_steps={:stacks=>'This will remove all files from the stacks that were shelved for the objects',
                      :dor=>'This will delete objects from Fedora',
                      :stage=>"This will delete the staged content in #{Assembly::ASSEMBLY_WORKSPACE}",
                      :symlinks=>"This will remove the symlink from #{Assembly::DOR_WORKSPACE}",
                      :workflows=>"This will remove the accessionWF and assemblyWF workflows"}

       num_steps=0

       puts 'THIS IS A DRY RUN' if dry_run

       Assembly::Utils.confirm "Run on '#{ENV['ROBOT_ENVIRONMENT']}'? Any response other than 'y' or 'yes' will stop the cleanup now." 
       Assembly::Utils.confirm "Are you really sure you want to run on production?  CLEANUP IS NOT REVERSIBLE" if ENV['ROBOT_ENVIRONMENT'] == 'production'

       steps.each do |step|
         if allowed_steps.keys.include?(step)
           Assembly::Utils.confirm "Run step '#{step}'?  #{allowed_steps[step]}.  Any response other than 'y' or 'yes' will stop the cleanup now."
           num_steps+=1 # count the valid steps found and agreed to
         end
       end

       raise "no valid steps specified for cleanup" if num_steps == 0
       raise "no druids provided" if druids.size == 0
       
       druids.each {|pid| Assembly::Utils.cleanup_object(pid,steps,dry_run)}

    end

    # Cleanup a single objects and associated files given a druid.  WARNING: VERY DESTRUCTIVE. 
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [string] pid a druid
    # @param [array] steps an array of steps, options below 
    #                :stacks=This will remove all files from the stacks that were shelved for the objects
    #                :dor=This will delete objects from Fedora
    #                :stage=This will delete the staged content in the assembly workspace
    #                :symlinks=This will remove the symlink from the dor workspace
    #                :workflows=This will remove the assemblyWF and accessoiningWF workflows for this object
    # @param [boolean] dry_run do not actually clean up (defaults to false)
    #
    # Example:
    #   Assembly::Utils.cleanup_object('druid:aa000aa0001',[:stacks,:dor,:stage,:symlinks,:workflows])
    def self.cleanup_object(pid,steps,dry_run=false)
      case ENV['ROBOT_ENVIRONMENT']
        when "test"
          stacks_server="stacks-test"
        when "production"
          stacks_server="stacks"
        when "development"
          stacks_server="stacks-dev"
      end
      begin
         # start up an SSH session if we are going to try and remove content from the stacks
         ssh_session=Net::SSH.start(stacks_server,'lyberadmin', :auth_methods => %w(gssapi-with-mic publickey hostbased password keyboard-interactive)) if steps.include?(:stacks) && defined?(stacks_server)
        
         druid_tree=DruidTools::Druid.new(pid).tree
         puts "Cleaning up #{pid}"
         if steps.include?(:dor)          
           puts "-- deleting #{pid} from Fedora #{ENV['ROBOT_ENVIRONMENT']}" 
           Assembly::Utils.unregister(pid) unless dry_run
         end
         if steps.include?(:symlinks)
           path_to_symlinks=[]
           path_to_symlinks << File.join(Assembly::DOR_WORKSPACE,druid_tree)
           path_to_symlinks << Assembly::Utils.get_staging_path(pid,Assembly::DOR_WORKSPACE)
           path_to_symlinks.each do |path|
             if File::directory?(path)
               puts "-- deleting folder #{path} (WARNING: should have been a symlink)"
               FileUtils::rm_rf path unless dry_run
             elsif File.symlink?(path)
               puts "-- deleting symlink #{path}"
               File.delete(path) unless dry_run
             else
               puts "-- Skipping #{path}: not a folder or symlink"
             end 
           end
         end
         if steps.include?(:stage)
           path_to_content=Assembly::Utils.get_staging_path(pid,Assembly::ASSEMBLY_WORKSPACE)
           puts "-- deleting folder #{path_to_content}"
           FileUtils.rm_rf path_to_content if !dry_run && File.exists?(path_to_content)
         end
         if steps.include?(:stacks)
           path_to_content= Dor::DigitalStacksService.stacks_storage_dir(pid)
           puts "-- removing files from the stacks on #{stacks_server} at #{path_to_content}"
           ssh_session.exec!("rm -fr #{path_to_content}") unless dry_run
         end
         if steps.include?(:workflows)
           puts "-- deleting #{pid} accessionWF and assemblyWF workflows from Fedora #{ENV['ROBOT_ENVIRONMENT']}" 
           unless dry_run
             Dor::WorkflowService.delete_workflow('dor',pid,'accessionWF')
             Dor::WorkflowService.delete_workflow('dor',pid,'assemblyWF')
           end
         end
       rescue Exception => e
         puts "** cleaning up failed for #{pid} with #{e.message}"
       end  
       ssh_session.close if ssh_session
    end
    
    # Delete an object from DOR.
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [string] pid the druid 
    #
    # Example:
    #   Assembly::Utils.delete_from_dor('druid:aa000aa0001')
    def self.delete_from_dor(pid)
      
      Dor::Config.fedora.client["objects/#{pid}"].delete
      Dor::SearchService.solr.delete_by_id(pid)
      Dor::SearchService.solr.commit
  
    end
    
    # Quicky update rights metadata for any existing list of objects using default rights metadata pulled from the supplied APO
    #
    # @param [array] druids - an array of druids
    # @param [string] apo_druid - the druid of the APO to pull rights metadata from
    # @param [boolean] publish - defaults to false, if true, will publish each object after replacing datastreams (must be run on server with rights to do this)
    #        
    # Example:
    #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
    #   apo_druid='druid:cc222cc2222'
    #   Assembly::Utils.update_rights_metadata(druids,apo_druid)    
    def self.update_rights_metadata(druids,apo_druid,publish=false)
      apo = Dor::Item.find(apo_druid)
      rights_md = apo.datastreams['defaultObjectRights']
      self.replace_datastreams(druids,'rightsMetadata',rights_md.content,publish)
    end
    
    # Replace a specific datastream for a series of objects in DOR with new content 
    #
    # @param [array] druids - an array of druids
    # @param [string] datastream_name - the name of the datastream to replace
    # @param [string] new_content - the new content to replace the entire datastream with
    # @param [boolean] publish - defaults to false, if true, will publish each object after replacing datastreams (must be run on server with rights to do this)
    #
    # Example:
    #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
    #   new_content='<xml><more nodes>this should be the whole datastream</more nodes></xml>'
    #   datastream='rightsMetadata'
    #   Assembly::Utils.replace_datastreams(druids,datastream,new_content)
    def self.replace_datastreams(druids,datastream_name,new_content,publish=false)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        ds = obj.datastreams[datastream_name]  
        if ds
          ds.content = new_content 
          ds.save
          puts "replaced #{datastream_name} for #{druid}"
          if publish
            obj.publish_metadata
            puts "--object re-published"
          end
        else
          puts "#{datastream_name} does not exist for #{druid}"          
        end
      end 
    end    

    # Republish a list of druids.  Only works when run from a server with access rights to the stacks (e.g. lyberservices-prod) 
    #
    # @param [array] druids - an array of druids
     #
     # Example:
     #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
     #   Assembly::Utils.republish(druids)
    def self.republish(druids)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        obj.publish_metadata
        puts "republished #{druid}"
      end
    end
    
    # Determines if the specifed APO object contains a specified workflow defined in it
    # DEPRACATED NOW THAT REIFED WORKFLOWS ARE USED
    # @param [string] druid - the druid of the APO to check
    # @param [string] workflow - the name of the workflow to check
    #  
    # @return [boolean] if workflow is defined in APO
    #  
    # Example:
    #   Assembly::Utils.apo_workflow_defined?('druid:oo000oo0001','assembly')
    # > true
    def self.apo_workflow_defined?(druid,workflow)
      puts "************WARNING - THIS METHOD MAY NOT BE USEFUL ANYMORE SINCE WORKFLOWS ARE NO LONGER DEFINED IN THE APO**************"
      obj = Dor::Item.find(druid)
      raise 'object not an APO' if obj.identityMetadata.objectType.first != 'adminPolicy'
      xml_doc=Nokogiri::XML(obj.administrativeMetadata.content)
      xml_doc.xpath("//#{workflow}").size == 1 || xml_doc.xpath("//*[@id='#{workflow}']").size == 1
    end
 
    # Determines if the specifed object is an APO
    # @param [string] druid - the druid of the APO to check
    #  
    # @return [boolean] if object exist and is an APO
    #  
    # Example:
    #   Assembly::Utils.is_apo?('druid:oo000oo0001')
    # > true
    def self.is_apo?(druid)
      begin
        obj = Dor::Item.find(druid)
        return obj.identityMetadata.objectType.first == 'adminPolicy'      
      rescue
        return false
      end
    end
    
    # Update a specific datastream for a series of objects in DOR by searching and replacing content 
    #
    # @param [array] druids - an array of druids
    # @param [string] datastream_name - the name of the datastream to replace
    # @param [string] find_content - the content to find
    # @param [string] replace_content - the content to replace the found content with
    #  
    # Example:
    #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
    #   find_content='FooBarBaz'
    #   replace_content='Stanford Rules'
    #   datastream='rightsMetadata'
    #   Assembly::Utils.update_datastreams(druids,datastream,find_content,replace_content)
    def self.update_datastreams(druids,datastream_name,find_content,replace_content)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        ds = obj.datastreams[datastream_name]
        if ds
          updated_content=ds.content.gsub(find_content,replace_content)  
          ds.content = updated_content
          ds.save
          puts "updated #{datastream_name} for #{druid}"
        else
          puts "#{datastream_name} does not exist for #{druid}"          
        end
      end 
    end    

    # Unregister a DOR object, which includes deleting it and deleting all its workflows
    #
    # @param [string] pid of druid
    #
    # @return [boolean] if deletion succeed or not    
    def self.unregister(pid)
      
      begin
        Assembly::Utils.delete_all_workflows pid
        Assembly::Utils.delete_from_dor pid
        return true
      rescue
        return false
      end
      
    end

    # Set the workflow step for the given PID to an error state
    #
    # @param [string] pid of druid
    # @param [string] step to set to error
    #
    def self.set_workflow_step_to_error(pid, step)
      wf_name = Assembly::ASSEMBLY_WF
      msg     = 'Integration testing'
      params  =  ['dor', pid, wf_name, step, msg]
      resp    = Dor::WorkflowService.update_workflow_error_status *params
      raise "update_workflow_error_status() returned false." unless resp == true
    end

    # Delete all workflows for the given PID.   Destructive and should only be used when deleting an object from DOR.
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [string] pid of druid
    # @param [String] repo repository dealing with the workflow.  Default is 'dor'.  Another option is 'sdr'
    # e.g. 
    # Assembly::Utils.delete_all_workflows('druid:oo000oo0001')
    def self.delete_all_workflows(pid, repo='dor')
      Dor::WorkflowService.get_workflows(pid).each {|workflow| Dor::WorkflowService.delete_workflow(repo,pid,workflow)}
    end

    # Reindex the supplied PID in solr.
    #
    # @param [string] pid of druid
    # e.g. 
    # Assembly::Utils.reindex('druid:oo000oo0001')    
    def self.reindex(pid)
      obj = Dor.load_instance pid
      solr_doc = obj.to_solr
      Dor::SearchService.solr.add(solr_doc, :add_attributes => {:commitWithin => 1000}) unless obj.nil?  
    end
    
    # Clear stray workflows - remove any workflow steps for orphaned objects.
    # This method only works when this gem is used in a project that is configured to connect to DOR
    def self.clear_stray_workflows
      repo      = 'dor'
      wf        = 'assemblyWF'
      msg       = 'Integration testing'
      wfs       = Dor::WorkflowService
      steps     = Assembly::ASSEMBLY_WF_STEPS.map { |s| s[0] }
      completed = steps[0]

      steps.each do |waiting|
        druids = wfs.get_objects_for_workstep completed, waiting, repo, wf
        druids.each do |dru|
          params = [repo, dru, wf, waiting, msg]
          resp = wfs.update_workflow_error_status *params
          puts "updated: resp=#{resp} params=#{params.inspect}"
        end
      end  
    end

    # Check if the object is full accessioned and ingested.
    # This method only works when this gem is used in a project that is configured to connect to the workflow service.
    #
    # @param [string] pid the druid to operate on
    #
    # @return [boolean] if object is fully ingested   
    # Example:
    #   Assembly::Utils.is_ingested?('druid:oo000oo0001')
    #   > false
    def self.is_ingested?(pid)
      WFS.get_lifecycle(REPO, pid, 'accessioned') ? true : false
    end

    # Check if the object is on ingest hold
    # This method only works when this gem is used in a project that is configured to connect to the workflow service.
    #
    # @param [string] pid the druid to operate on
    #
    # @return [boolean] if object is on ingest hold
    # Example:
    #   Assembly::Utils.ingest_hold?('druid:oo000oo0001')
    #   > false
    def self.ingest_hold?(pid)
      WFS.get_workflow_status(REPO, pid, 'accessionWF','sdr-ingest-transfer') == 'hold'
    end
 
    # Check if the object is submitted
    # This method only works when this gem is used in a project that is configured to connect to the workflow service.
    #
    # @param [string] pid the druid to operate on
    #
    # @return [boolean] if object is submitted   
    # Example:
    #   Assembly::Utils.is_submitted?('druid:oo000oo0001')
    #   > false   
    def self.is_submitted?(pid)
      WFS.get_lifecycle(REPO, pid, 'submitted') == nil
    end
    
    # Reset the workflow states for a list of druids given a list of workflow names and steps.
    # Provide a list of druids in an array, and a hash containing workflow names (e.g. 'assemblyWF' or 'accessionWF') as the keys, and arrays of steps
    # as the corresponding values (e.g. ['checksum-compute','jp2-create']) and they will all be reset to "waiting".
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [Hash] params parameters specified as a hash, using symbols for options:
    #   * :druids => array of druids
    #   * :steps => a hash, containing workflow names as keys, and an array of steps
    #   * :state => a string for the name of the state to reset to, defaults to 'waiting' (could be 'completed' for example)
    #
    # Example:
    #   druids=['druid:aa111aa1111','druid:bb222bb2222']
    #   steps={'assemblyWF'  => ['checksum-compute'],'accessionWF' => ['content-metadata','descriptive-metadata']}
    #   Assembly::Utils.reset_workflow_states(:druids=>druids,:steps=>steps)
    def self.reset_workflow_states(params={})
      druids=params[:druids] || []
      workflows=params[:steps] || {}
      state=params[:state] || "waiting"
      druids.each do |druid|
      	puts "** #{druid}"
      	begin
      	    workflows.each do |workflow,steps| 
      	      steps.each do |step| 
      	        puts "Updating #{workflow}:#{step} to #{state}"
      	        Dor::WorkflowService.update_workflow_status 'dor',druid,workflow, step, state
              end
            end
          rescue Exception => e
      		  puts "an error occurred trying to update workflows for #{druid} with message #{e.message}"
      	end
      end
    end

    # Get a list of druids from a CSV file which has a heading of "druid" and put them into a Ruby array.
    # Useful if you want to import a report from argo
    #
    # @param [string] filename of CSV that has a column called "druid"
    #
    # @return [array] array of druids
    #
    # Example:
    #   Assembly::Utils.read_druids_from_file('download.csv') # ['druid:xxxxx','druid:yyyyy']
    def self.read_druids_from_file(csv_filename)
      rows=CsvMapper.import(csv_filename) do read_attributes_from_file end
      druids=[]
      rows.each do |row|
        druid=row.druid
        druid="druid:#{druid}" unless druid.include?('druid:')
        druids << druid
      end
      return druids
    end
    
    # Get a list of druids that have errored out in a particular workflow and step
    #
    # @param [string] workflow name
    # @param [string] step name
    # @param [string] tag -- optional, if supplied, results will be filtered by the exact tag supplied; note this will dramatically slow down the response if there are many results
    #
    # @return [hash] hash of results, with key has a druid, and value as the error message
    # e.g. 
    # result=Assembly::Utils.get_errored_objects_for_workstep('accessionWF','content-metadata','Project : Revs')
    # => {"druid:qd556jq0580"=>"druid:qd556jq0580 - Item error; caused by #<Rubydora::FedoraInvalidRequest: Error modifying datastream contentMetadata for druid:qd556jq0580. See logger for details>"}
    def self.get_errored_objects_for_workstep workflow, step, tag = ''
      result=Dor::WorkflowService.get_errored_objects_for_workstep workflow,step,'dor'
      if tag == ''
        return result
      else
        filtered_result={}
        result.each do |druid,error|
          begin
            item=Dor::Item.find(druid)
            filtered_result.merge!(druid=>error) if item.tags.include? tag
          rescue
          end
        end
        return filtered_result
      end
    end

    # Reset any objects in a specific workflow step and state that have errored out back to waiting
    #
    # @param [string] workflow name
    # @param [string] step name
    # @param [string] tag -- optional, if supplied, results will be filtered by the exact tag supplied; note this will dramatically slow down the response if there are many results
    #
    # @return [hash] hash of results that have been reset, with key has a druid, and value as the error message
    # e.g. 
    # result=Assembly::Utils.reset_errored_objects_for_workstep('accessionWF','content-metadata')
    # => {"druid:qd556jq0580"=>"druid:qd556jq0580 - Item error; caused by #<Rubydora::FedoraInvalidRequest: Error modifying datastream contentMetadata for druid:qd556jq0580. See logger for details>"}    
    def self.reset_errored_objects_for_workstep workflow, step, tag=''
      result=self.get_errored_objects_for_workstep workflow,step,tag
      druids=[]
      result.each {|k,v| druids << k}
      self.reset_workflow_states(:druids=>druids,:steps=>{workflow=>[step]}) if druids.size > 0
      return result
    end

    # Read in a list of druids from a pre-assembly progress load file and load into an array.
    #
    # @param [string] progress_log_file filename
    # @param [boolean] completed if true, returns druids that have completed, if false, returns druids that failed (defaults to true)
    #
    # @return [array] list of druids
    #
    # Example:    
    #   druids=Assembly::Utils.get_druids_from_log('/dor/preassembly/sohp_accession_log.yaml')
    #   puts druids
    #   > ['aa000aa0001','aa000aa0002']
    def self.get_druids_from_log(progress_log_file,completed=true)
       druids=[]
       docs = YAML.load_stream(Assembly::Utils.read_file(progress_log_file))
       docs = docs.documents if docs.respond_to? :documents
       docs.each { |obj| druids << obj[:pid] if obj[:pre_assem_finished] == completed}   
       return druids
    end

    # Read in a YAML configuration file from disk and return a hash
    #
    # @param [string] filename of YAML config file to read
    #
    # @return [hash] configuration contents as a hash
    #
    # Example:
    #   config_filename='/thumpers/dpgthumper2-smpl/SC1017_SOHP/sohp_prod_accession.yaml'
    #   config=Assembly::Utils.load_config(config_filename)   
    #   puts config['progress_log_file']
    #   > "/dor/preassembly/sohp_accession_log.yaml" 
    def self.load_config(filename)
      YAML.load(Assembly::Utils.read_file(filename))  
    end

    # Read in a file from disk
    #
    # @param [string] filename to read
    #
    # @return [string] file contents as a string
    def self.read_file(filename)
      return File.readable?(filename) ? IO.read(filename) : ''
    end

    # Used by the completion_report and project_tag_report in the pre-assembly project 
    #
    # @param [solr_document] doc a solr document result
    # @param [boolean] check_status_in_dor indicates if we should check for the workflow states in dor or trust SOLR is up to date (defaults to false)
    #
    # @return [string] a comma delimited row for the report
    def self.solr_doc_parser(doc,check_status_in_dor=false)
      
      druid = doc[:id]

      if Solrizer::VERSION < '3.0'
        label = doc[:objectLabel_t]
        title=doc[:public_dc_title_t].nil? ? '' : doc[:public_dc_title_t].first

        if check_status_in_dor
          accessioned = self.get_workflow_status(druid,'accessionWF','publish')=="completed"
          shelved = self.get_workflow_status(druid,'accessionWF','shelve')=="completed"
        else
          accessioned = doc[:wf_wps_facet].nil? ? false : doc[:wf_wps_facet].include?("accessionWF:publish:completed")
          shelved = doc[:wf_wps_facet].nil? ? false : doc[:wf_wps_facet].include?("accessionWF:shelve:completed")
        end
        source_id = doc[:source_id_t]
        files=doc[:content_file_t]
      else
        label = doc[Solrizer.solr_name('objectLabel', :displayable)]
        title = doc.fetch(Solrizer.solr_name('public_dc_title', :displayable), []).first || ''

        if check_status_in_dor
          accessioned = self.get_workflow_status(druid,'accessionWF','publish')=="completed"
          shelved = self.get_workflow_status(druid,'accessionWF','shelve')=="completed"
        else
          accessioned = doc.fetch(Solrizer.solr_name('wf_wps', :symbol), []).include?("accessionWF:publish:completed")
          shelved = doc.fetch(Solrizer.solr_name('wf_wps', :symbol), []).include?("accessionWF:shelve:completed")
        end
        source_id = doc[Solrizer.solr_name('source_id', :symbol)]
        files=doc[Solrizer.solr_name('content_file', :symbol)]

      end

		  if files.nil?
				file_type_list=""
				num_files=0
			else
		  	num_files = files.size			
				# count the amount of each file type
				file_types=Hash.new(0)
				unless num_files == 0
					files.each {|file| file_types[File.extname(file)]+=1}
					file_type_list=file_types.map{|k,v| "#{k}=#{v}"}.join(' | ')
				end
		  end
		
	    purl_link = ""
	    val = druid.split(/:/).last
	    purl_link = File.join(Assembly::PURL_BASE_URL, val)
      
      return  [druid, label, title, source_id, accessioned, shelved, purl_link, num_files,file_type_list]   
       
    end

    # Takes a hash data structure and recursively converts all hash keys from strings to symbols.
    #
    # @param [hash] h hash
    #
    # @return [hash] a hash with all keys converted from strings to symbols
    #
    # Example:
    #   Assembly::Utils.symbolize_keys({'dude'=>'is cool','i'=>'am too'})
    #   > {:dude=>"is cool", :i=>"am too"} 
    def self.symbolize_keys(h)
      if h.instance_of? Hash
        h.inject({}) { |hh,(k,v)| hh[k.to_sym] = symbolize_keys(v); hh }
      elsif h.instance_of? Array
        h.map { |v| symbolize_keys(v) }
      else
        h
      end
    end

    # Takes a hash and converts its string values to symbols -- not recursively.
    #
    # @param [hash] h hash
    #
    # @return [hash] a hash with all keys converted from strings to symbols
    #
    # Example:
    #   Assembly::Utils.values_to_symbols!({'dude'=>'iscool','i'=>'amtoo'})
    #   > {"i"=>:amtoo, "dude"=>:iscool} 
    def self.values_to_symbols!(h)
      h.each { |k,v| h[k] = v.to_sym if v.class == String }
    end    

    # Removes any duplicate tags within each druid
    #
    # @param [array] druids - an array of druids
    def self.remove_duplicate_tags(druids)
      druids.each do |druid|
        i = Dor::Item.find(druid)
        if i and i.tags.size > 1 # multiple tags
          i.tags.each do |tag|
            if (i.tags.select {|t| t == tag}).size > 1 # tag is duplicate
              i.remove_tag(tag)
              i.add_tag(tag)
              puts "Saving #{druid} to remove duplicate tag='#{tag}'"
              i.save
            end
          end 
        end
      end
    end

    private
    # Used by the cleanup to ask user for confirmation of each step.  Any response other than 'yes' results in the raising of an error 
    #
    # @param [string] message the message to show to a user
    #
    def self.confirm(message)
      puts message
      response=gets.chomp.downcase
      raise "Exiting" if response != 'y' && response != 'yes'
    end

  end
  
end
