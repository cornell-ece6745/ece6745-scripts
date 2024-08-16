#=========================================================================
# setup-ece2300.sh [-q]
#=========================================================================
# This setup script is for ECE 2300. It will set various environment
# variables every time it is run, but can also run some heavier weight
# commands once when an account is first initialized.

#-------------------------------------------------------------------------
# Do nothing if this is not an interactive shell
#-------------------------------------------------------------------------

if [[ ! $- =~ "i" ]]; then
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

if [[ "x$1" == "x--enable-auto-setup" ]] || [[ "x$2" == "x--enable-auto-setup" ]]; then
  enable_auto_setup="yes"
else
  enable_auto_setup="no"
fi

if [[ "x$1" == "x--disable-auto-setup" ]] || [[ "x$2" == "x--disable-auto-setup" ]]; then
  disable_auto_setup="yes"
else
  disable_auto_setup="no"
fi

#-------------------------------------------------------------------------
# print
#-------------------------------------------------------------------------
# Helper function which displays its argument as long as we have not set
# the -q command line option.

function print
{
  if [[ "x${quiet}" == "xno" ]]; then
    echo "$1"
  fi
}

function printn
{
  if [[ "x${quiet}" == "xno" ]]; then
    echo -n "$1"
  fi
}

#-------------------------------------------------------------------------
# append_to_pathlist
#-------------------------------------------------------------------------
# This is a useful helper function which we will use in our setup scripts
# to add a path to a pathlist. The function first checks to see if the
# path is already on the pathlist, and if so it removes the path. Once we
# know that the path is not already on the pathlist, we append it to the
# front of the path list. This makes sourcing setup scripts idempotent,
# i.e., we can source setup scripts multiple times without any impact on
# the overall setup.

function append_to_pathlist
{
  # get pathlist into local pathlist (add : at end)
  eval "temp_pathlist=\$$1:"

  # remove new path from local pathlist if exists
  temp_pathlist=${temp_pathlist//"$2:"}

  # append new path to front of local pathlist
  if [[ "${temp_pathlist}" == ":" ]]; then
    temp_pathlist="$2"
  else
    temp_pathlist="$2:${temp_pathlist}"
  fi

  # set pathlist to local pathlist (remove : at end)
  export $1=${temp_pathlist%":"}
}

#-------------------------------------------------------------------------
# Make sure this script is only sourced once
#-------------------------------------------------------------------------

if [[ "x${SETUP_ECE2300}" == "xyes" ]]; then
  print ""
  print " It looks like you have already sourced the setup-ece2300.sh"
  print " script, so we are not going to do any additional setup."
  print " You should be all set. If for some reason you were trying"
  print " to see the effect of an updated version of the setup script"
  print " then just log out, log back into ecelinux, and source the"
  print " setup script again."
  print ""
  return
fi

#-------------------------------------------------------------------------
# Make sure ece5745 script has not been sourced
#-------------------------------------------------------------------------

if [[ "x${SETUP_ECE5745}" == "xyes" ]]; then
  echo ""
  echo " It looks like you have already sourced the setup-ece5745.sh"
  echo " script, but you can only source the setup-ece5745.sh script"
  echo " _or_ the setup-ece2300.sh script ... not both! If you did"
  echo " not explicitly source the setup-ece5745.sh script, then it"
  echo " is probably being sourced automatically in your .bashrc"
  echo " file. Open the $HOME/.bashrc file using geany or your"
  echo " favorite text editor and remove any lines which source"
  echo " setup-ece5745.sh. Then log out and log back into ecelinux."
  echo ""
  return
fi

#-------------------------------------------------------------------------
# Make sure no other course setup script has been sourced
#-------------------------------------------------------------------------
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash

if [[ ! -z "${SETUP_COURSE}" ]]; then
  echo ""
  echo " It looks like you have already sourced the setup-${SETUP_COURSE}.sh"
  echo " script, but you can only source ONE setup script at a time!"
  echo " If you did not explicitly source the setup-${SETUP_COURSE}.sh"
  echo " script, then it is probably being sourced automatically"
  echo " in your .bashrc file. Open the $HOME/.bashrc file using"
  echo " geany or your favorite text editor and remove any lines"
  echo " which source setup-${SETUP_COURSE}.sh. Then log out and log"
  echo " back into ecelinux. You will need to explicitly source the"
  echo " appropriate setup script before working on a course, and"
  echo " log out and log back in to work on a different course."
  echo ""
  return
fi

#-------------------------------------------------------------------------
# Set environment variable so we know this script has been sourced
#-------------------------------------------------------------------------

export SETUP_COURSE="ece2300"
export SETUP_ECE2300="yes"

#-------------------------------------------------------------------------
# Start
#-------------------------------------------------------------------------

print ""
print " Running ECE 2300 setup script"

#-------------------------------------------------------------------------
# Determine if we need to rerun initialization commands
#-------------------------------------------------------------------------
# Some of these commands only need to be done once, the very first time a
# user logs into their account. To try and reduce overhead, we keep a
# file in the users home directory called .setup-ece2300 which has a
# counter. If the last count is less than the count we are looking for,
# then we update the count and rerun these initialization commands. This
# way we can force users to rerun initialization commands by simply
# increasing the count.

run_init_cmds_last_ver="?"
run_init_cmds_curr_ver="1"
run_init_cmds="yes"
if [[ -f "${HOME}/.setup-ece2300" ]]; then
  run_init_cmds_last_ver=$(tail -1 "${HOME}/.setup-ece2300")
  if [[ "${run_init_cmds_curr_ver}" == "${run_init_cmds_last_ver}" ]]; then
    run_init_cmds="no"
  fi
fi

print "  - Determine init commands version number: ${run_init_cmds_last_ver}"

if [[ "${run_init_cmds}" == "yes" ]]; then
  print "  - Initialization commands outdated, will be rerun"
  echo "${run_init_cmds_curr_ver}" >> "${HOME}/.setup-ece2300"
fi

#-------------------------------------------------------------------------
# Determine which platform we are running on
#-------------------------------------------------------------------------
# The ECE 2300 setup script is only meant to be run on ecelinux, so we
# simply check that it is running on the correct servers and hard code
# the ARCH environment variable.

case "$(hostname)" in
  ecelinux-*.ece.cornell.edu)       server_class="ecelinux" ;;
  # en-ec-ph314-*.ece.cornell.edu)  server_class="ecelinux" ;;
  *)                                server_class="unknown"  ;;
esac

if [[ ${server_class} == "unknown" ]]; then
  print ""
  print " The ECE 2300 tools are not supported on this machine."
  print " The course is only supported on ecelinux machines."
  print ""
  return
fi

#-------------------------------------------------------------------------
# SSH Keys
#-------------------------------------------------------------------------

if [[ ! -f "${HOME}/.ssh/ece2300-github.pub" ]]; then

  print "  - Setting up ssh keys for accessing github"

  netid=$(whoami)
  ssh-keygen -q -N "" -t rsa -C "${netid}@cornell.edu" -f "${HOME}/.ssh/ece2300-github"

  echo ""                                     >> "${HOME}/.ssh/config"
  echo "# added by setup-ece2300.sh"          >> "${HOME}/.ssh/config"
  echo "Host github.com"                      >> "${HOME}/.ssh/config"
  echo "  IdentityFile ~/.ssh/ece2300-github" >> "${HOME}/.ssh/config"
  echo ""                                     >> "${HOME}/.ssh/config"

fi

if ! grep -q "# key/X11 forwarding added by setup-ece2300.sh" "${HOME}/.ssh/config"; then

  print "  - Running ssh initialization to ensure key/X11 forwarding enabled"

  echo ""                          >> "${HOME}/.ssh/config"
  echo "# key/X11 forwarding added by setup-ece2300.sh" >> "${HOME}/.ssh/config"
  echo ""                          >> "${HOME}/.ssh/config"
  echo "Host *.ece.cornell.edu"    >> "${HOME}/.ssh/config"
  echo "  ForwardAgent  yes"       >> "${HOME}/.ssh/config"
  echo "  ForwardX11    yes"       >> "${HOME}/.ssh/config"
  echo ""                          >> "${HOME}/.ssh/config"
  echo "Host *.coecis.cornell.edu" >> "${HOME}/.ssh/config"
  echo "  ForwardAgent  yes"       >> "${HOME}/.ssh/config"
  echo "  ForwardX11    yes"       >> "${HOME}/.ssh/config"
  echo ""                          >> "${HOME}/.ssh/config"

fi

#-------------------------------------------------------------------------
# SSH Permissions
#-------------------------------------------------------------------------
# Always set permissions to avoid ssh errors

print "  - Setting up ssh permissions"

chmod 700 ~/.ssh
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/ece2300-github.pub
chmod 600 ~/.ssh/ece2300-github

#-------------------------------------------------------------------------
# Setup environment modules
#-------------------------------------------------------------------------

export ECE2300_INSTALL="/classes/ece2300/install"
export PATH="${ECE2300_INSTALL}/pkgs/modules-5.4.0/bin:${PATH}"
source "${ECE2300_INSTALL}/pkgs/modules-5.4.0/init/bash"

module use "${ECE2300_INSTALL}/modules"

export MODULES_COLORS="hi=1:db=2:tr=2:se=2:er=91:wa=93:me=95:in=94:mp=1;94:di=94:al=96:va=93:sy=95:de=4:cm=92:aL=4:L=4;32:H=2:F=41:nF=43:S=46:sS=44:kL=30;48;5;109"
export MODULES_COLLECTION_PIN_VERSION=1

#-------------------------------------------------------------------------
# Load environment modules
#-------------------------------------------------------------------------


#-------------------------------------------------------------------------
# Git initialization commands
#-------------------------------------------------------------------------

if [[ "${run_init_cmds}" == "yes" ]]; then

  print "  - Running git initialization commands"

  # Include git config from the install directories

  if [[ -d "${ECE2300_INSTALL}/pkgs/ece2300-scripts-0.0/etc/gitconfig.d" ]]; then
    for file in $(find "${ECE2300_INSTALL}/pkgs/ece2300-scripts-0.0/etc/gitconfig.d" -type f); do
      git config --global include.path "${file}"
    done
  fi

  netid=$(whoami)
  git config --global user.name  "${netid}"
  git config --global user.email "${netid}@cornell.edu"

fi

#-------------------------------------------------------------------------
# Default editor
#-------------------------------------------------------------------------

print "  - Setting the default editor to nano"

export EDITOR="nano"

#-------------------------------------------------------------------------
# Setup Prompt
#-------------------------------------------------------------------------
# We used to not mess with a user's prompt, but students kept forgetting
# to source the setup script. So now we change the prompt to make it
# obvious that (1) they have sourced the setup scripts, and (2) what
# directory they are currently working in.

print "  - Setting up prompt"

PS1="\[\e[1;34m\]ECE2300:\[\e[0m\] \[\e[1m\]\w\[\e[0m\] % "
export PROMPT_DIRTRIM=2

#-------------------------------------------------------------------------
# Auto setup
#-------------------------------------------------------------------------

print "  - enable  auto setup: ${enable_auto_setup}"
print "  - disable auto setup: ${disable_auto_setup}"

if [[ "${enable_auto_setup}" == "yes" ]]; then

  print "  - removing line to source setup script from .bashrc"

  rm -rf ${HOME}/.bashrc.bak
  sed -i.bak -e '/# ECE2300 BEGIN SETUP/,/# ECE2300 END SETUP/d' ${HOME}/.bashrc

  print "  - adding line to source setup script to .bashrc"
  echo "# ECE2300 BEGIN SETUP"                     >> ${HOME}/.bashrc
  echo ""                                          >> ${HOME}/.bashrc
  echo "source /classes/setup/setup-ece2300.sh -q" >> ${HOME}/.bashrc
  echo ""                                          >> ${HOME}/.bashrc
  echo "# ECE2300 END SETUP"                       >> ${HOME}/.bashrc

  echo ""
  echo " NOTE: Your login script has been updated so that it will"
  echo " automatically source the setup script every time you log"
  echo " ecelinux. You can disable this behavior with this command:"
  echo ""
  echo "  % source setup-ece2300.sh --disable-auto-setup"
  echo ""
  echo " After disabling auto setup you will need manually source"
  echo " the setup script every time you want to work on the course"

fi

if [[ "${disable_auto_setup}" == "yes" ]]; then

  print "  - removing line to source setup script from .bashrc"

  rm -rf ${HOME}/.bashrc.bak
  sed -i.bak -e '/# ECE2300 BEGIN SETUP/,/# ECE2300 END SETUP/d' ${HOME}/.bashrc

  echo ""
  echo " NOTE: Your login script has been updated so that it will"
  echo " no longer automatically source the setup script every time"
  echo " you log into ecelinux.  You will need manually source"
  echo " the setup script every time you want to work on the course"

fi

#-------------------------------------------------------------------------
# Done
#-------------------------------------------------------------------------

if [[ "x$1" != "x-n" ]] && [[ "x$2" != "x-n" ]]; then
  print ""
fi

