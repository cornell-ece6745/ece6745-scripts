#=========================================================================
# setup-gui.sh
#=========================================================================
# Checks to see if Xvnc is running and if so sets the DISPLAY variable
# appropriately so launching any GUI application will open in Xvnc.
#
# Author : Christopher Batten
# Date   : February 8, 2025

#-------------------------------------------------------------------------
# Initial checks
#-------------------------------------------------------------------------

# Check if setup-brg.sh has been sourced

if [[ "x${SETUP_ECE6745}" != "xyes" ]]; then
  echo ""
  echo " The setup-ece6745.sh script has not been sourced yet. Please"
  echo " source setup-ece6745.sh and then resource this setup script."
  echo ""
  return
fi

#-------------------------------------------------------------------------
# Command line processing
#-------------------------------------------------------------------------

if [[ "x$1" == "x-v" ]] || [[ "x$2" == "x-v" ]]; then
  quiet="no"
else
  quiet="yes"
fi

#-------------------------------------------------------------------------
# Start
#-------------------------------------------------------------------------

print ""
print " Running GUI setup script"

#-------------------------------------------------------------------------
# Check if Xvnc is running
#-------------------------------------------------------------------------

print "  - Check if Xvnc is running"

xvnc_running=$(ps -u $USER -o pid,cmd | grep '[X]vnc')

if [[ -z "$xvnc_running" ]]; then
  echo ""
  echo " Could not find a running instance of Xvnc. Before sourcing this"
  echo " setup script, you have to use Microsoft Remote Desktop to log"
  echo " into $(hostname)."
  echo ""
  return
fi

#-------------------------------------------------------------------------
# Get Xvnc port
#-------------------------------------------------------------------------

xvnc_port=$(ps -u $USER -o pid,cmd | grep '[X]vnc' | cut -d' ' -f4)

print "  - Xnvc command line: ${xvnc_running}"
print "  - Xnvc port: ${xvnc_port}"

#-------------------------------------------------------------------------
# Setup environment variables
#-------------------------------------------------------------------------
# Set the DISPLAY environment variable so any new X11 apps will open in
# the Xvnc desktop.

print "  - Setup environment variables"

export DISPLAY="${xvnc_port}.0"

print ""

