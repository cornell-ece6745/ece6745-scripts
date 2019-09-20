#=========================================================================
# setup-ece4750.sh [-q]
#=========================================================================
# This setup script is for ECE 4750. It will set various environment
# variables every time it is run, but can also run some heavier weight
# commands once when an account is first initialized.

#-------------------------------------------------------------------------
# Command line processing
#-------------------------------------------------------------------------

if [[ "x$1" == "x-q" ]] || [[ "x$2" == "x-q" ]]; then
  quiet="yes"
else
  quiet="no"
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
# Make sure no other course setup script has been sourced
#-------------------------------------------------------------------------
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash

if [[ ! -z "${SETUP_COURSE}" ]]; then
  print ""
  print " It looks like you have already sourced the setup-${SETUP_COURSE}.sh"
  print " script, but you can only source ONE setup script at a time!"
  print " If you did not explicitly source the setup-${SETUP_COURSE}.sh"
  print " script, then it is probably being sourced automatically"
  print " in your .bashrc file. Open the $HOME/.bashrc file using"
  print " geany or your favorite text editor and remove any lines"
  print " which source setup-${SETUP_COURSE}.sh. Then log out and log"
  print " back into ecelinux. You will need to explicitly source the"
  print " appropriate setup script before working on a course, and"
  print " log out and log back in to work on a different course."
  print ""
  return
fi

#-------------------------------------------------------------------------
# Set environment variable so we know this script has been sourced
#-------------------------------------------------------------------------

export SETUP_COURSE="ece4750"
export SETUP_ECE4750="yes"

#-------------------------------------------------------------------------
# Start
#-------------------------------------------------------------------------

print ""
print " Running ECE 4750 setup script"

#-------------------------------------------------------------------------
# Determine if we need to rerun initialization commands
#-------------------------------------------------------------------------
# Some of these commands only need to be done once, the very first time a
# user logs into their account. To try and reduce overhead, we keep a
# file in the users home directory called .setup-ece4750 which has a
# counter. If the last count is less than the count we are looking for,
# then we update the count and rerun these initialization commands. This
# way we can force users to rerun initialization commands by simply
# increasing the count.

run_init_cmds_last_ver="?"
run_init_cmds_curr_ver="2"
run_init_cmds="yes"
if [[ -f "${HOME}/.setup-ece4750" ]]; then
  run_init_cmds_last_ver=$(tail -1 "${HOME}/.setup-ece4750")
  if [[ "${run_init_cmds_curr_ver}" == "${run_init_cmds_last_ver}" ]]; then
    run_init_cmds="no"
  fi
fi

print "  - Determine init commands version number: ${run_init_cmds_last_ver}"

if [[ "${run_init_cmds}" == "yes" ]]; then
  print "  - Initialization commands outdated, will be rerun"
  echo "${run_init_cmds_curr_ver}" >> "${HOME}/.setup-ece4750"
fi

#-------------------------------------------------------------------------
# Determine which platform we are running on
#-------------------------------------------------------------------------
# The ECE 4750 setup script is only meant to be run on ecelinux, so we
# simply check that it is running on the correct servers and hard code
# the ARCH environment variable.

case "$(hostname)" in
  en-ec-ecelinux-*.coecis.cornell.edu) server_class="ecelinux" ;;
  en-ec-ph314-*.ece.cornell.edu)       server_class="ecelinux" ;;
  *)                                   server_class="unknown"  ;;
esac

if [[ ${server_class} == "unknown" ]]; then
  print ""
  print " The ECE 4750 tools are not supported on this machine."
  print " The toolflow is only supported on ecelinux machines."
  print ""
  return
fi

# Set the ARCH environment variable appropriately

export ARCH="x86_64-rhel7"

print "  - Determine platform: ${ARCH}"

#-------------------------------------------------------------------------
# Global package install paths
#-------------------------------------------------------------------------

# Setup global package installs for ECE 4750

print "  - Setting up global package install paths"

export STOW_PKGS_GLOBAL_ROOT="/classes/ece4750/install/stow-pkgs"
export STOW_PKGS_GLOBAL_PREFIX="${STOW_PKGS_GLOBAL_ROOT}/${ARCH}"

export BARE_PKGS_GLOBAL_ROOT="/classes/ece4750/install/bare-pkgs"
export BARE_PKGS_GLOBAL_PREFIX="${BARE_PKGS_GLOBAL_ROOT}/${ARCH}"

export RVM_PKGS_GLOBAL_ROOT="/classes/ece4750/install/rvm-pkgs"
export RVM_PKGS_GLOBAL_PREFIX="${RVM_PKGS_GLOBAL_ROOT}/${ARCH}"

append_to_pathlist PATH            "${STOW_PKGS_GLOBAL_ROOT}/noarch/bin"
append_to_pathlist PATH            "${STOW_PKGS_GLOBAL_PREFIX}/bin"
append_to_pathlist PKG_CONFIG_PATH "${STOW_PKGS_GLOBAL_PREFIX}/share/pkgconfig"
append_to_pathlist PKG_CONFIG_PATH "${STOW_PKGS_GLOBAL_PREFIX}/lib/pkgconfig"

#-------------------------------------------------------------------------
# Local package install paths
#-------------------------------------------------------------------------

print "  - Setting up local package install paths"

export STOW_PKGS_ROOT="${HOME}/install/stow-pkgs"
export STOW_PKGS_PREFIX="${STOW_PKGS_ROOT}/${ARCH}"

append_to_pathlist PATH            "${STOW_PKGS_ROOT}/noarch/bin"
append_to_pathlist PATH            "${STOW_PKGS_PREFIX}/bin"
append_to_pathlist PKG_CONFIG_PATH "${STOW_PKGS_PREFIX}/share/pkgconfig"
append_to_pathlist PKG_CONFIG_PATH "${STOW_PKGS_PREFIX}/lib/pkgconfig"

export BARE_PKGS_ROOT="${HOME}/install/bare-pkgs"
export BARE_PKGS_PREFIX="${BARE_PKGS_ROOT}/${ARCH}"

#-------------------------------------------------------------------------
# SSH Keys
#-------------------------------------------------------------------------

if [[ ! -f "${HOME}/.ssh/ece4750-github.pub" ]]; then

  print "  - Setting up ssh keys for accessing github"

  netid=$(whoami)
  ssh-keygen -q -N "" -t rsa -C "${netid}@cornell.edu" -f "${HOME}/.ssh/ece4750-github"

  echo ""                                     >> "${HOME}/.ssh/config"
  echo "# added by setup-ece4750.sh"          >> "${HOME}/.ssh/config"
  echo "Host github.com"                      >> "${HOME}/.ssh/config"
  echo "  IdentityFile ~/.ssh/ece4750-github" >> "${HOME}/.ssh/config"
  echo ""                                     >> "${HOME}/.ssh/config"

fi


if ! grep -q "# key/X11 forwarding added by setup-ece4750.sh" "${HOME}/.ssh/config"; then

  print "  - Running ssh initialization to ensure key/X11 forwarding enabled"

  echo ""                          >> "${HOME}/.ssh/config"
  echo "# key/X11 forwarding added by setup-ece4750.sh" >> "${HOME}/.ssh/config"
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
chmod 600 ~/.ssh/ece4750-github.pub
chmod 600 ~/.ssh/ece4750-github

#-------------------------------------------------------------------------
# Python environment
#-------------------------------------------------------------------------
# We use a global virtualenv as a way to manage our globally installed
# Python packages. Note that we save the prompt and then restore it to
# avoid virtualenv's prompt prefix. Since this is meant to be the global
# default Python installation, it is not really necessary to clutter up
# the user's prompt. We do _not_ use the VIRTUAL_ENV_DISABLE_PROMPT
# environment variable since that would disable virtualenv prompts when
# we do future activates as well.

print "  - Setting up global Python virtualenv [PyPy-5.4.1]"

export VENV_PKGS_GLOBAL_ROOT="/classes/ece4750/install/venv-pkgs/${ARCH}"

ps_temp="$PS1"
# source ${VENV_PKGS_GLOBAL_ROOT}/python2.7.12/bin/activate
# Shunning: since Oct 16, 2016, we switch to pypy for the global venv

source ${VENV_PKGS_GLOBAL_ROOT}/pypy5.4.1/bin/activate

PS1="${ps_temp}"

#-------------------------------------------------------------------------
# Verilator environment
#-------------------------------------------------------------------------

# print "  - Setting up environment for Verilator"

# We make sure that VERILATOR_ROOT is _not_ set. This is because we are
# using stow to install verilator so the verilator paths are already
# hard-coded into the installation. From the manual:
#
# VERILATOR_ROOT
# Specifies the directory containing the distribution kit. This is used
# to find the executable, Perl library, and include files. If not
# specified, it will come from a default optionally specified at
# configure time (before Verilator was compiled). It should not be
# specified if using a pre-compiled Verilator RPM as the hardcoded
# value should be correct.

unset VERILATOR_ROOT

# We don't need to set PYMTL_VERILATOR_INCLUDE_DIR anymore sincye PyMTL
# now can find Verilator using pkg-config.

#-------------------------------------------------------------------------
# Git initialization commands
#-------------------------------------------------------------------------

if [[ "${run_init_cmds}" == "yes" ]]; then

  print "  - Running git initialization commands"

  # Include git config from the install directories

  if [[ -d "${STOW_PKGS_ROOT}/noarch/etc/gitconfig.d" ]]; then
    for file in $(find "${STOW_PKGS_ROOT}/noarch/etc/gitconfig.d" -type f); do
      git config --global include.path "${file}"
    done
  fi

  if [[ -d "${STOW_PKGS_GLOBAL_ROOT}/noarch/etc/gitconfig.d" ]]; then
    for file in $(find "${STOW_PKGS_GLOBAL_ROOT}/noarch/etc/gitconfig.d" -type f); do
      git config --global include.path "${file}"
    done
  fi

  netid=$(whoami)
  git config --global user.name  "${netid}"
  git config --global user.email "${netid}@cornell.edu"

fi

#-------------------------------------------------------------------------
# Geany initialization commands
#-------------------------------------------------------------------------

if [[ ! -f "${HOME}/.config/geany/geany.conf" ]]; then

  print "  - Running geany initialization commands"

  mkdir -p $HOME/.config/geany
  print "" > $HOME/.config/geany/geany.conf

  print "[geany]"                                  >> $HOME/.config/geany/geany.conf
  print "pref_editor_tab_width=2"                  >> $HOME/.config/geany/geany.conf
  print "indent_type=0"                            >> $HOME/.config/geany/geany.conf
  print "long_line_column=74"                      >> $HOME/.config/geany/geany.conf
  print "line_break_column=74"                     >> $HOME/.config/geany/geany.conf
  print "pref_toolbar_use_gtk_default_style=false" >> $HOME/.config/geany/geany.conf
  print "pref_toolbar_use_gtk_default_icon=false"  >> $HOME/.config/geany/geany.conf
  print "pref_toolbar_icon_size=2"                 >> $HOME/.config/geany/geany.conf
  print "msgwindow_visible=false"                  >> $HOME/.config/geany/geany.conf

  print "[plugins]"                                >> $HOME/.config/geany/geany.conf
  print "active_plugins=/usr/lib64/geany/filebrowser.so;/usr/lib64/geany/splitwindow.so;" >> $HOME/.config/geany/geany.conf

fi

#-------------------------------------------------------------------------
# Make .local/share directory
#-------------------------------------------------------------------------
# Geany needs to store some information in .local/share and complains if
# this directory does not exist. So we just make sure this directory is
# always created.

if [[ ! -d "${HOME}/.local/share" ]]; then

  print "  - Creating ~/.local/share"

  mkdir -p "${HOME}/.local/share"

fi

#-------------------------------------------------------------------------
# Default editor
#-------------------------------------------------------------------------

print "  - Setting the default editor to nano"

export EDITOR="nano"

#-------------------------------------------------------------------------
# Setup LaTeX
#-------------------------------------------------------------------------

print "  - Setting up the texlive-2016 LaTeX distribution"

module load texlive-2016

#-------------------------------------------------------------------------
# Setup Ruby
#-------------------------------------------------------------------------

print "  - Setting up global Ruby RVM environment"

source ${RVM_PKGS_GLOBAL_PREFIX}/scripts/rvm

#-------------------------------------------------------------------------
# Setup Aliases
#-------------------------------------------------------------------------

alias riscv32-objdump="riscv32-unknown-elf-objdump -dC --no-show-raw-insn -Mno-aliases -Mnumeric"

#-------------------------------------------------------------------------
# Setup Prompt
#-------------------------------------------------------------------------
# We used to not mess with a user's prompt, but students kept forgetting
# to source the setup script. So now we change the prompt to make it
# obvious that (1) they have sourced the setup scripts, and (2) what
# directory they are currently working in.

print "  - Setting up prompt"

PS1="\[\e[1;34m\]ECE4750:\[\e[0m\] \[\e[1m\]\w\[\e[0m\] % "
export PROMPT_DIRTRIM=2

#-------------------------------------------------------------------------
# Done
#-------------------------------------------------------------------------

if [[ "x$1" != "x-n" ]] && [[ "x$2" != "x-n" ]]; then
  print ""
fi

