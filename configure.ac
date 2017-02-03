#=========================================================================
# Toplevel configure.ac for the ECE 4750 scripts
#=========================================================================

#-------------------------------------------------------------------------
# Project metadata
#-------------------------------------------------------------------------

m4_define( proj_name,         [ECE 4750 Scripts])
m4_define( proj_maintainer,   [Christopher Batten])
m4_define( proj_abbreviation, [ece4750-scripts])

#-------------------------------------------------------------------------
# Project version information
#-------------------------------------------------------------------------
# Version information is meant to be managed through a version control
# system's tags and revision numbers. In a working copy the version will
# not be defined here (you should just use the version control system's
# mechanisms). When we make a distribution then we can set the version
# here as formed by the scripts/vcs-version.sh script so that the
# distribution knows what version it came from. If you are not using
# version control then it is fine to set this directly.

m4_define( proj_version, [?])

#-------------------------------------------------------------------------
# Setup
#-------------------------------------------------------------------------

AC_INIT(proj_name,proj_version,proj_maintainer,proj_abbreviation)
AC_CONFIG_SRCDIR([bin/setup-ece4750.sh])
AC_CONFIG_AUX_DIR([scripts])
AC_CANONICAL_BUILD
AC_CANONICAL_HOST

# Stow-based installation
AX_PROG_STOW_PKGS_NOARCH_INSTALL

#-------------------------------------------------------------------------
# Check git version
#-------------------------------------------------------------------------

req_git_ver=1.6
AC_CHECK_PROG([have_git],[git],[yes],[no])
AC_CACHE_CHECK(
 [if git version is >= ${req_git_ver}],
 [ac_cv_git_ver],
[
  ac_cv_git_ver="no"
  AS_IF([ test ${have_git} = "yes" ],
  [
    git_ver=`git --version | cut -c 13-`
    AX_COMPARE_VERSION([${git_ver}],[gt],[${req_git_ver}],
      [ac_cv_git_ver="yes"])
  ])
])

AS_IF([ test ${have_git} = "no" || test ${ac_cv_git_ver} = "no" ],
[
  AC_MSG_ERROR([ECE 4750 Git Scripts require git version >= ${req_git_ver}])
])

#-------------------------------------------------------------------------
# Output
#-------------------------------------------------------------------------

AC_CONFIG_FILES([Makefile])
AC_OUTPUT

