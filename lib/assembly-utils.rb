module Assembly
    
    PURL_BASE_URL='http://purl.stanford.edu'
    
    CONTENT_MD_FILE='contentMetadata.xml'
    DESC_MD_FILE='descMetadata.xml'

     # Defaut workspace and assembly areas, used in cleanup
     DOR_WORKSPACE='/dor/workspace'
     ASSEMBLY_WORKSPACE='/dor/assembly'  # can be overwritten by the value set in the project specific YAML configuration

     ASSEMBLY_WF='assemblyWF'
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
