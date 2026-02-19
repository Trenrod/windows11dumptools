# Creates Dumps 

Here are all scripts and files to create `umdh` Dumps and Diffs.
Which can be used for further analysis of memory leaks.

## Usage

### Create memory allocation dumps from `Local` UCServers

```ps1
# Make sure your are in the ./tools/DumpCollector directory
cd .\tools\DumpCollector\

# Example start
# DumpPath - dumps root path where the app is looking for the diffs
# SubfolderName - $DumpPath\SubfolderName\[timestamp] will be the folder name where all dumps are stored
# IntervalMinutes - Wait between dump creation in minutes (decimal allowed)
# Iterations - How many dumps should be taken
.\makeLocalSnapshots.ps1 -DumpPath ..\..\dumps\ -SubfolderName local  -IntervalMinutes 1 -Iterations 5
```

### Create memory allocation dumps from `NEX` UCServers

Requires to have access to the specific kubernetes cluster and namespaces

```ps1
# Make sure your are in the ./tools/DumpCollector directory
cd .\tools\DumpCollector\

# Example start
# DumpPath - Root path of the dumps
# UCSID - UCSID of the NEX instance
# Environment - aka K8s namespace  where the pod runs
# IntervalMinutes - Wait between dump creation in minutes (decimal allowed)
# Iterations - How many dumps should be taken
.\makeNEXSnapshots.ps1 -DumpPath ..\..\dumps\ -IntervalMinutes 5 -Iterations 24 -UCSID zugaquwohu -Environment ucaas-provisioner-production
```

# FAQ

## EUCSrv Symbols do not load

- Make sure you dont have a Network interface with IPv6 enabled
- Make sure `\\build\symbols` is reachable from your machine/explorer
- Make sure `\\builddrv.estos.de\build` is reachable from your machine/explorer
- Make sure `\\alf\alf-x` is reachable from your machine/explorer
- Make sure symbols for the version of your UCServer have been created