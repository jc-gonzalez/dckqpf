# dckqpf

## Introduction

DockerQPF is a set of scripts to launch a containerized (Docker) version of QPF, as well as a container with the PostgreSQL server running.  The data folders, as well as the configuration files folder, is bind-mounted from local host folders.  This makes the contents of these folder to be persistent across QPF launches.

## Tools

This package includes 2 main tools:

- `DockerQPF-create.sh`: Creates Docker images from Dockerfiles included, and eventually pull from or push to a configured NEXUS repository

- `DockerQPF-launch.sh`: Launches the Docker containers specified at command line, eventually cleaning the set of finished containers.

The usage of the different tools is as shown in the following sections.

### DockerQPF-create.sh

Usage:

    DockerQPF-create.sh [ -h ] [ -b | -d ] [ -p ] [ -C ] [ -c ] [ -u ] [ -o "opts" ]

where:

      -h         Show this usage message
      -b         Build the specified images
      -d         Download from Nexus repository, instead of build
      -p         PostgreSQL image
      -C         COTS base image for QPF
      -c         QPF Core image
      -u         Upload to Nexus repository, after creation
      -o "opts"  Specify options

### DockerQPF-launch.sh

Usage:

    DockerQPF-launch.sh [ -h ] [ -P ] [ -b ] [ -C ] [ -K ] [ -z ]

where:

      -h         Show this usage message
      -p         Start PostgreSQL Server Container
      -b         Initialize QPF DB
      -C         Clear DB
      -K         Kill running PostgreSQL & QPF Master Core Containers
      -z         Remove old Docker Containers


## Example of execution

Initial setup and launch could be as follows:

    $ DockerQPF-create.sh -p -c -d
    $ DockerQPF-launch.sh -K -z -b -p 
    
The first line downloads (`-d`) the images for PostgreSQL (`-p`) and QPF Core (`-c`) from the NEXUS repository.  

The second line kills (`-K`) currently running copies of the PostgreSQL and QPF Core, removes all exited (`-z`) containers, initializes the QPF database (`-b`), and executes the PostgreSQL (`-p`) as well as the QPF Core (always).

