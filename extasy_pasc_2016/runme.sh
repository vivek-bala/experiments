#!/bin/bash

## NOTES: This script is to automate the process of running the workflows scripts with different 
## configurations. You can log on to a persistent machine and use tmux to open a new session. 
## INSTANCES is the number of simulations to be executed
## CORES is the number of cores to be reserved
## (INSTANCE,CORE) gives us a data point.
## ITERS is the number of times the experiment is to be repeated for every (INSTANC,CORE)
## datapoint in order to obtain an average and stddev.

## Requirements: Download the tarballs from the documentation page. Open the resource config file,
## set the username, walltime(estimate) and PILOTSIZE=CORES. Open the kernel config file,
## set num_CUs=INSTANCES and number of iterations to 1 and nsave=2. Place this script in the same
## folder as the root workflow folder (grlsd-on-stampede/, coam-on-archer/, etc).


## TMUX quick-brief:
## tmux new -s <session_name>
## (make sure you enable the virtualenv again in this new session)
## Ctrl+d to detach from the session
## tmux a -t <session_name> to attach back to the session
## DO NOT EXIT THE SESSION. ONLY DETACH !

ITERS="3"
INSTANCES="16 32 64 128 512 1024 2048"       #Weak scaling
#INSTANCES="2048"                            #Strong scaling
CORES="16 32 64 128 512 1024 2048"

ORIG="`pwd`"

#rm -rf dait
mkdir -p data				# Folder with all the data

for iter in `seq 1 $ITERS`
do
	for size in $CORES
	do
		for inst in $INSTANCES
		do
			if [ $inst -eq $size ];               #Weak scaling. Remove if-condition for strong scaling.
			then
				export EXPERIMENT=experiment_iter${iter}_p${size}_i${inst}
				cd $ORIG/data
				rm -rf $EXPERIMENT
				mkdir -p $EXPERIMENT
				cd $EXPERIMENT					# Folder for this datapoint

				# Copy necessary files and folders into the above folder				
				cp ../../extasy_amber_coco.py .			#coam
				#cp ../../extasy_gromacs_lsdmap.py .	#grlsd
				cp ../../inp_files . -r
				cp ../../helper_scripts . -r
				cp ../../kernel_defs . -r

				# Replace variables in the config files with datapoint values				
				cat ../../stampede.rcfg | sed -e "s/CORES/$size/g" > stampede.rcfg					
				#cat ../../archer.rcfg | sed -e "s/CORES/$size/g" > archer.rcfg
				cat ../../cocoamber.wcfg | sed -e "s/INSTANCES/$inst/g" > cocoamber.wcfg			#coam
				#cat ../../gromacslsdmap.wcfg | sed -e "s/INSTANCES/$inst/g" > gromacslsdmap.wcfg 	#grlsd

				# Run the script with the specific datapoints
				# You can comment the following line and run this script to see how the folder structure 
				# comes out
				python extasy_amber_coco.py --RPconfig stampede.rcfg --Kconfig cocoamber.wcfg
			fi
		done
	done
done

