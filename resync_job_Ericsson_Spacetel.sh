#!/bin/sh
# ############################################################################ #
# Purpose: Automated Resync Script to perform the resync task on need basis.   #
# Description: Check OC Instance for resync. Whenever OC has Resynchronization #
#	       parameter is True, Script performs Resync for the same.	       #
# Author: Mukul Varshney						       #
# Last Modification Time: Wed Oct  9 12:40:52 IST 2013
# ############################################################################ #

# Trap Signal if Some One tries to kill the script.
trap 'echo "Encountered a kill statement executed on the script during the session";exit 9' 1 3 9 11 15
# Global variable declaration.
export BASE_LOC='/var/opt/temip/scripts/HPONM/RESYNCJOB_NEEDBASIS/resyncJob'
export OC_LIST=${BASE_LOC}/oclist.txt
export TEMP_JOB_PREFIX="TMP_resyncJob"
export TEMP_JOB_SUFFIX='$(date +'%Y%m%d%H%M').job'
export LOG_FILE=${BASE_LOC}/temp_jobs/log/resync_main_$(date +'%Y%m%d').log
export DATE_HR=$(date +'%H')
export DATE_MIN=$(date +'%M')

#>$LOG_FILE

# Check Process count, if already running than exit with status 1.
export CurrentJobID=$$
export PROC_NAME="resyncJob\/resync_job_Ericsson_Spacetel\.sh"
export PROC_RUN_COUNT=`ps -aef|grep $PROC_NAME|grep -v -e grep -e $CurrentJobID -e "sh \-c"|wc -l`

if [ $PROC_RUN_COUNT -ge 1 ];then . ${BASE_LOC}/daemon_def.inc; log_message 'Resync Script is already running.';exit 1; fi

while true
do

if [ $DATE_HR -eq 00 -a $DATE_MIN -eq 00 ];then exit 0;fi

# Read re-sync daemon definition.
. ${BASE_LOC}/daemon_def.inc

#log_message '\n\n\n'
#log_message "Reading definition from daemon_def.inc"

# Get the list of OC Instances.
#log_message "Collecting the list of all OC Instances."
OC_INSTANCE_LIST=$(cat $OC_LIST | grep -v ^# | awk -F"|" '{if($1!="")print $1}' | sort -u)

for INSTANCE_ID in $OC_INSTANCE_LIST
do
	export INSTANCE_ID
	
	# Check OC Instances status/state. If running for a particular OC Instance, Send a mail saying re-sync is in progress for the OC Instance.
	# Else If the not running then start manual resync job and initiate a mail saying re-sync is started for the OC Instance.
	# Re-Sync should be started after validating below conditions:
	# 	a. The "Resynchronization Needed" flag of the instance should be true.
	#	b. A re-sync for the same instance is not running.
	#	c. More than 2 re-sync job shouldn’t be running in back-end.
	#log_message "Checking Instance Resynchronization Needed parameter."
	checkOCstatus $INSTANCE_ID

	# Status can be 0 or >0.
	# Zero(0)	=> Re-Sync for the Instance is already running.
	# One(1)	=> Re-Sync fot the Instance should be started.
	if [ $? -eq 0 ]
	then
		# Initiate a mail saying "Re-Sync for the OC Instance: <INSTANCE_ID> is running, Please follow up the status".
		# sendMailX $?
		echo -e "\c"
	else
		# Perform the mandatory checks and start Re-Sync Job for the particular OC INSTANCE.
		# Initiate the mail saying "Re-Sync for the OC Instance \'<INSTANCE_ID>\' is started."
		# After completion of re-sync, Initiate the mail saying "Re-Sync for the OC Instance \'<INSTANCE_ID>\' is completed."
		# Activate the packets for the particular OC, To sync RCA with RAW alarms.
		# Change the value of the parameter "Resynchronization Needed" = "False" for the OC Instance.
		# sendMailX $?
		reSync $INSTANCE_ID
	fi
done
sleep 5

# Archive 2 days old job scripts and their respective logfiles. Also removing 7 days old job scripts and their respective logfiles.
find $BASE_LOC/temp_jobs -mtime +2 -name "*.job" -exec mv {} $BASE_LOC/temp_jobs/archive/ \; 2>/dev/null
gzip ${BASE_LOC}/temp_jobs/archive/*.job 2>/dev/null
find ${BASE_LOC}/temp_jobs/log -mtime +2 -name "*.log" -exec mv {} ${BASE_LOC}/temp_jobs/log/archive/ \; 2>/dev/null
gzip ${BASE_LOC}/temp_jobs/log/archive/*.log 2>/dev/null
find ${BASE_LOC}/temp_jobs/archive/ -mtime +7 -name "*.job" -exec rm {} \; 2>/dev/null
find ${BASE_LOC}/temp_jobs/log/archive/ -mtime +7 -name "*.log" -exec rm {} \; 2>/dev/null

export DATE_HR=$(date +'%H')
export DATE_MIN=$(date +'%M')
done
