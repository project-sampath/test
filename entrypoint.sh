#!/bin/bash
set -e

BOLD='\033[1m'
NC='\033[0m \n' #No Color
JBOSS_CLI=$JBOSS_HOME/bin/jboss-cli.sh
JBOSS_STANDALONE=$JBOSS_HOME/bin/standalone.sh
DEPLOYMENT_DIR=/pega/deploy/*
PATCH_DIR=$HOME/patches

function logMessage() {
	echo ""
	printf "${BOLD}---> $1${NC}"
	echo ""
}

function applyPatches() {
	logMessage "Applying JBoss Patches..."
	for patch in `ls $PATCH_DIR/*.zip | sort -V`
	do
		startJBoss
		waitServerStart
		logMessage "Applying JBoss Patch $patch..."
		$JBOSS_CLI -c "patch apply $patch"
		stopJBoss
		logMessage "JBoss Patch $patch successfully applied. Removing it from filesystem..."
		rm $patch
	done;
	logMessage "JBoss Patches successfully applied."
}

function applyPegaCustomizations() {
	logMessage "Applying Pega custom settings..."
	logMessage "Backing up JBoss standalone.conf..."
	mv $JBOSS_HOME/bin/standalone.conf $JBOSS_HOME/bin/standalone.conf.origin
	logMessage "Replacing JBoss standalone.conf with Pega custom version..."
	cp $JBOSS_HOME/bin/standalone.conf.pega $JBOSS_HOME/bin/standalone.conf
	logMessage "Pega custom settings successfully applied."
}

function startJBoss () {
	logMessage "Starting JBoss..."
	$JBOSS_STANDALONE -b 0.0.0.0 -bmanagement 0.0.0.0 -c standalone-full.xml &
}

function waitServerStart () {
	until `$JBOSS_CLI -c "ls /deployment" &> /dev/null`; do
	 sleep 1
 	done
	logMessage "JBoss Server started."
}

function configureJBoss () {
	logMessage "Configuring JBoss..."
	#sed -i "s/<resolve-parameter-values>false<\/resolve-parameter-values>/<resolve-parameter-values>true<\/resolve-parameter-values>/" $JBOSS_HOME/bin/jboss-cli.xml
	startJBoss
	waitServerStart
	$JBOSS_CLI -c --properties=/pega/etc/datasources.properties --file=$JBOSS_HOME/bin/PegaConfig.cli
	stopJBoss
	logMessage "JBoss Configured."
}

function deployApps () {
	logMessage "Deploying Pega Applications..."
	for f in $DEPLOYMENT_DIR
	do
		logMessage "Deploying $f archive..."
	  $JBOSS_CLI -c "deploy $f"
	done
	logMessage "Pega Applications Deployed."
}

function stopJBoss () {
	logMessage "JBoss shutdown initiated..."
 	$JBOSS_CLI -c ":shutdown(timeout=60)"
	logMessage "JBoss shutdown completed."
}

function finish() {
	stopJBoss
	logMessage "Exit..."
	exit
}

# Prevent owner issues on mounted folders
#sudo chown -R jboss: -R /pega
case "$1" in
	'')
		#Check if JBOSS is configured
		if [ -d "$JBOSS_HOME/modules/com/oracle/jdbc/main" ]; then
			logMessage "JBoss already initialized."
			startJBoss
		else
			logMessage "JBoss not initialized. Initializing JBoss..."
			applyPatches
			applyPegaCustomizations
			configureJBoss
			startJBoss
			waitServerStart
			logMessage "JBoss successfully initialized."
			logMessage "Please visit http://<container_ip>:$JBOSS_MGMT_HTTP_PORT/console to open JBoss console.\n     Visit http://<container_ip>:$JBOSS_HTTP_PORT/prweb to open Pega Designer Studio."
		fi

		##
		## Workaround for graceful shutdown.
		##
		while [ "$END" == '' ]; do
			sleep 1
			trap finish INT TERM
		done
		;;

	*)
		logMessage "Pega JBoss domain is not configured! Please run '/entrypoint.sh' if needed"
		$1
		;;
esac
