[![Build Status](https://travis-ci.org/sul-dlss/assembly-utils.png?branch=master)](https://travis-ci.org/sul-dlss/assembly-utils)

# Assembly Utils Gem

## Overview
Ruby gem of methods useful for assembly and accessioning. Contains classes to
manipulate DOR objects for assembly and accessioning.

## Releases

*   1.0.0 initial release
*   1.0.1 bug fixes
*   1.0.2 more bug fixes to use the new druid-tools namespace
*   1.0.3 add a method to compute staging paths based on changes to Druid gem path computations
*   1.0.4 add some tests and document methods
*   1.0.5 add more spec tests and documentation; update `get_staging_path` method to fix a bug
*   1.0.6 add the ability to delete workflows in the cleanup method, add a new
    method to fetch and delete all workflows
*   1.0.7 add a new method to determine if a specific workflow is defined in the APO
*   1.0.8 add methods to batch import and export objects to/from FOXML
*   1.0.9 add spec output test data directory to git
*   1.0.10 lowered required version of dor-services from 3.9.0 to 3.8.0
*   1.0.11 use `Dor::DigitalStacksService` to calculate stacks directory to cleanup
*   1.0.12 bugfix on call to `Dor::DigitalStacksService`
*   1.0.13 update to latest lyberteam devel gems
*   1.0.14 add new method to re-index item in solr
*   1.1.0  small updates to some methods to depracate `apo_workflow` checking method
*   1.1.1  add dor-workflow-service gem and convenience method to auto reset
    all objects in a specific state back to waiting
*   1.1.2  allow `reset_workflow_state` to accept a state parameter
*   1.1.3  add a reindex method
*   1.1.4  fixed delete object method to remove from solr too; fix cleanup
    object method to remove both old and new style druid trees
*   1.1.5 add new claim druid method
*   1.1.6 add new step to remove workflows during `cleanup_object`
*   1.1.7 change ordering of cleanup steps so if deleting workflow fails, the
    earlier steps will still run
*   1.1.8 fix bug in cleanup method during symlink deletion
*   1.1.9 add remediate-object to the workflow status report; remove some
    methods around robot usage that aren't needed anymore
*   1.2.0 add a new method to return an array of druids from a CSV file which contains a "druid" column
*   1.2.1 add a new method to insert a specific workflow into an object
*   1.2.2 add a new method to bulk republish a list of druids, and a new
    parameter to datastreams bulk update to publish after updating
*   1.2.3 add a new method to check the status of an object (`is_ingested?`)
*   1.2.4 add some additional methods to check the state of an object
*   1.2.5-1.2.7  update gemfile to newer version of dor-services gem and other related/dependent gems
*   1.2.8 add a new constant for technical metadata filename
*   1.4.1-2 update gems and fix typos
*   1.4.6 rubocop fixes, and other refactoring
*   1.5.0 relax dependency pinning to support rails 5, and dor-workflow-service

## Running tests

You will need to be on the Stanford network or VPNed in to run the
tests, since it connects to DOR.  To run tests:

```bash
bundle exec rspec spec
```

## Deploy new gem

```bash
gem build assembly-utils.gemspec
gem push assembly-utils-1.4.1.gem # update version as needed
```

## Connecting to DOR

Some of the methods require a connection to DOR, which is not provided as part
of this gem.  In order to connect to DOR, you will need some configuration
information in your project, along with the certificates for the appropriate
environment.  Connections for development DOR are provided as part of the gem
in the 'config' directory and are used in the spec test suite.
