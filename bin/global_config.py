#=========================================================================
# global_config
#=========================================================================
#
# Author : Khalid Al-Hawaj
# Date   : August 26, 2017

class global_config():

  def __init__( self ):
    # Store the following configuration in a configuration file
    # default to the following if nothing has been provided
    self.server_port = 1024
    self.server_addr = 'ecelinux-01.ece.cornell.edu'
