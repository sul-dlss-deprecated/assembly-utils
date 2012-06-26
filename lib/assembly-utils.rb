module Assembly
    
end
require 'dor-services'

Dor::Config.configure do

  assembly do

    # Defaut workspace and assembly areas, used in cleanup
    dor_workspace      '/dor/workspace'
    assembly_workspace '/dor/assembly'  # can be overwritten by the value set in the project specific YAML configuration
    
    # The assembly workflow parameters
    # TODO Remove these when they are no longer needed to unregister an object
    assembly_wf  'assemblyWF'
    assembly_wf_steps [
      [ 'start-assembly',        'completed' ],
      [ 'jp2-create',            'waiting'   ],
      [ 'checksum-compute',      'waiting'   ],
      [ 'exif-collect',          'waiting'   ],
      [ 'accessioning-initiate', 'waiting'   ],
    ]
  end

end

# auto-include all files in the lib sub-directory directory
Dir[File.dirname(__FILE__) + '/assembly-utils/*.rb'].each {|file| require file unless file=='verison.rb'}
