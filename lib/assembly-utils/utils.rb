require 'net/ssh'
require 'csv'

module Assembly

  # The Utils class contains methods to help with accessioning and assembly
  class Utils

    # Get the staging directory tree given a druid, and optionally prepend a basepath.
    #
    # @param [String] pid druid pid (e.g. 'aa000aa0001')
    # @param [String] base_path optional base path to prepend to druid path
    #
    # @return [string] path to material that is being staged, with optional prepended base path
    #
    # Example:
    #   puts Assembly::Utils.get_staging_path('aa000aa0001','tmp')
    #   > "tmp/aa/000/aa/0001"
    def self.get_staging_path(pid,base_path='')
      d=DruidTools::Druid.new(pid,base_path)
      path=File.dirname(d.path)
      path.slice!(0) if base_path=='' && path[0]==47 # remove first / if base_path is empty
      return path
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

    # Tells you the status of the assembly and accessioning robots on the server the command is run on.
    #
    # @return [string] output to let you know if robots are running
    #
    # Example:
    #   puts Assembly::Utils.robot_status
    #   > Accession robots are NOT running
    #   > Assembly robots are NOT running   
    def self.robot_status
    
      accession_robots="ps -ef | grep accessionWF | wc -l"
      assembly_robots="ps -ef | grep assemblyWF | wc -l"
      puts "Accession robots are " +  (`#{accession_robots}`.strip.to_i > 3 ? "running" : "NOT running")
      puts "Assembly robots are " +  (`#{assembly_robots}`.strip.to_i > 2 ? "running" : "NOT running")

    end

    # Tells you the commands you need to execute on a unix prompt to actually start the assembly and accession robots.
    # Does NOT execute the commands themselves.
    #
    # @return [string] output to let you know how to start robots
    #
    # Example:
    #   puts Assembly::Utils.start_robots
    #   > cd /home/lyberadmin/common-accessioning/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start accessionWF:content-metadata accessionWF:descriptive-metadata accessionWF:rights-metadata accessionWF:remediate-object accessionWF:publish accessionWF:shelve accessionWF:provenance-metadata accessionWF:cleanup
    #   > cd /home/lyberadmin/assembly/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start assemblyWF:jp2-create assemblyWF:checksum-compute assemblyWF:exif-collect assemblyWF:accessioning-initiate
    def self.start_robots
            
      accession_robots="cd /home/lyberadmin/common-accessioning/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start accessionWF:content-metadata accessionWF:descriptive-metadata accessionWF:rights-metadata accessionWF:remediate-object accessionWF:publish accessionWF:shelve accessionWF:provenance-metadata accessionWF:cleanup"
      assembly_robots="cd /home/lyberadmin/assembly/current; ROBOT_ENVIRONMENT=#{ENV['ROBOT_ENVIRONMENT']} ./bin/run_robot start assemblyWF:jp2-create assemblyWF:checksum-compute assemblyWF:exif-collect assemblyWF:accessioning-initiate"
      
      puts "To start robots:"
      puts "#{accession_robots}"
      puts "#{assembly_robots}" 

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

      accession_steps = %w(content-metadata	descriptive-metadata rights-metadata shelve publish)
      assembly_steps = Assembly::ASSEMBLY_WF_STEPS.map { |s| s[0] }

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
    # @return [string] workflow step status
    #
    # Example:
    #   puts Assembly::Utils.get_workflow_status('druid:aa000aa0001','assemblyWF','jp2-create')
    #   > "completed"
    def self.get_workflow_status(druid,workflow,step)
      begin
        result=Dor::WorkflowService.get_workflow_status('dor', druid, workflow, step)  
      rescue
        result='NOT FOUND'
      end
      return result
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
     #
     #   * :dry_run =>  do not actually clean up (defaults to false)
     #
     # Example:
     #   Assembly::Utils.cleanup(:druids=>['druid:aa000aa0001','druid:aa000aa0002'],:steps=>[:stacks,:dor,:stage,:symlinks])
     def self.cleanup(params={})
       
       druids=params[:druids] || []
       steps=params[:steps] || []
       dry_run=params[:dry_run] || false
       
       allowed_steps={:stacks=>'This will remove all files from the stacks that were shelved for the objects',
                      :dor=>'This will delete objects from Fedora',
                      :stage=>"This will delete the staged content in #{Assembly::ASSEMBLY_WORKSPACE}",
                      :symlinks=>"This will remove the symlink from #{Assembly::DOR_WORKSPACE}"}

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
    # @param [boolean] dry_run do not actually clean up (defaults to false)
    #
    # Example:
    #   Assembly::Utils.cleanup_object('druid:aa000aa0001',[:stacks,:dor,:stage,:symlinks])
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
         ssh_session=Net::SSH.start(stacks_server,'lyberadmin') if steps.include?(:stacks) && defined?(stacks_server)
        
         druid_tree=DruidTools::Druid.new(pid).tree
         puts "Cleaning up #{pid}"
         if steps.include?(:dor)
           puts "-- deleting #{pid} from Fedora #{ENV['ROBOT_ENVIRONMENT']}" 
           Assembly::Utils.unregister(pid) unless dry_run
         end
         if steps.include?(:symlinks)
           path_to_symlink=File.join(Assembly::DOR_WORKSPACE,druid_tree)
           puts "-- deleting symlink #{path_to_symlink}"
           File.delete(path_to_symlink) if !dry_run && File.exists?(path_to_symlink)
         end
         if steps.include?(:stage)
           path_to_content=File.join(Assembly::ASSEMBLY_WORKSPACE,druid_tree)
           puts "-- deleting folder #{path_to_content}"
           FileUtils.rm_rf path_to_content if !dry_run && File.exists?(path_to_content)
         end
         if steps.include?(:stacks)
           path_to_content=File.join('/stacks',druid_tree)
           puts "-- removing files from the stacks on #{stacks_server} at #{path_to_content}"
           ssh_session.exec!("rm -fr #{path_to_content}") unless dry_run
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
  
    end
    
    # Quicky update rights metadata for any existing list of objects using default rights metadata pulled from the supplied APO
    #
    # @param [array] druids - an array of druids
    # @param [string] apo_druid - the druid of the APO to pull rights metadata from
    #        
    # Example:
    #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
    #   apo_druid='druid:cc222cc2222'
    #   Assembly::Utils.update_rights_metadata(druids,apo_druid)    
    def self.update_rights_metadata(druids,apo_druid)
      apo = Dor::Item.find(apo_druid)
      rights_md = apo.datastreams['defaultObjectRights']
      self.replace_datastreams(druids,'rightsMetadata',rights_md.content)
    end
    
    # Replace a specific datastream for a series of objects in DOR with new content 
    #
    # @param [array] druids - an array of druids
    # @param [string] datastream_name - the name of the datastream to replace
    # @param [string] new_content - the new content to replace the entire datastream with
    #
    # Example:
    #   druids=%w{druid:aa111aa1111 druid:bb222bb2222}
    #   new_content='<xml><more nodes>this should be the whole datastream</more nodes></xml>'
    #   datastream='rightsMetadata'
    #   Assembly::Utils.replace_datastreams(druids,datastream,new_content)
    def self.replace_datastreams(druids,datastream_name,new_content)
      druids.each do |druid|
        obj = Dor::Item.find(druid)
        ds = obj.datastreams[datastream_name]  
        if ds
          ds.content = new_content 
          ds.save
          puts "replaced #{datastream_name} for #{druid}"
        else
          puts "#{datastream_name} does not exist for #{druid}"          
        end
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

    # Unregister a DOR object, which includes deleting it and setting all workflow assembly steps to an error state
    #
    # @param [string] pid of druid
    def self.unregister(pid)
      
      begin
        # Set all assemblyWF steps to error.
        steps = Assembly::ASSEMBLY_WF_STEPS
        steps.each { |step, status|  Assembly::Utils.set_workflow_step_to_error pid, step }

        # Delete object from Dor.
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

    # Reset the workflow states for a list of druids given a list of workflow names and steps.
    # Provide a list of druids in an array, and a hash containing workflow names (e.g. 'assemblyWF' or 'accessionWF') as the keys, and arrays of steps
    # as the corresponding values (e.g. ['checksum-compute','jp2-create']) and they will all be reset to "waiting".
    # This method only works when this gem is used in a project that is configured to connect to DOR
    #
    # @param [Hash] params parameters specified as a hash, using symbols for options:
    #   * :druids => array of druids
    #   * :steps => a hash, containing workflow names as keys, and an array of steps
    #
    # Example:
    #   druids=['druid:aa111aa1111','druid:bb222bb2222']
    #   steps={'assemblyWF'  => ['checksum-compute'],'accessionWF' => ['content-metadata','descriptive-metadata']}
    #   Assembly::Utils.reset_workflow_states(:druids=>druids,:steps=>steps)
    def self.reset_workflow_states(params={})
      druids=params[:druids] || []
      steps=params[:steps] || {}
      druids.each do |druid|
      	puts "** #{druid}"
      	begin
      	    steps.each do |workflow,states| 
      	      states.each do |state| 
      	        puts "Updating #{workflow}:#{state} to waiting"
      	        Dor::WorkflowService.update_workflow_status 'dor',druid,workflow, state, 'waiting'
              end
            end
          rescue Exception => e
      		  puts "an error occurred trying to update workflows for #{druid} with message #{e.message}"
      	end
      end
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
       YAML.each_document(Assembly::Utils.read_file(progress_log_file)) { |obj| druids << obj[:pid] if obj[:pre_assem_finished] == completed}  
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
