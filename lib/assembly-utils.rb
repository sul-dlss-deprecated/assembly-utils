module Assembly
    
    # Base PURL URL
    PURL_BASE_URL='http://purl.stanford.edu'
    
    # Default content metadata file present at root of each object directory
    CONTENT_MD_FILE='contentMetadata.xml'

    # Default descriptive metadata file present at root of each object directory
    DESC_MD_FILE='descMetadata.xml'

     # Defaut DOR workspace directory
     DOR_WORKSPACE='/dor/workspace'
     
     # Default assembly directory, can be overwritten by the value set in the project specific YAML configuration
     ASSEMBLY_WORKSPACE='/dor/assembly'

     # Assembly workflow name
     ASSEMBLY_WF='assemblyWF'
     
     # Assembly workflow steps, used for cleanup
     ASSEMBLY_WF_STEPS=[
       [ 'start-assembly',        'completed' ],
       [ 'jp2-create',            'waiting'   ],
       [ 'checksum-compute',      'waiting'   ],
       [ 'exif-collect',          'waiting'   ],
       [ 'accessioning-initiate', 'waiting'   ],
     ]    
     
end

require 'dor-services'
# auto-include all files in the lib sub-directory directory
Dir[File.dirname(__FILE__) + '/assembly-utils/*.rb'].each {|file| require file unless file=='version.rb'}
