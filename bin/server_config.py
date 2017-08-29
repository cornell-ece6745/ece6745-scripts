#=========================================================================
# server_config
#=========================================================================
#
# Author : Khalid Al-Hawaj
# Date   : August 26, 2017

class server_config():

  def __init__( self ):
    # Store the following configuration in a configuration file
    # default to the following if nothing has been provided
    self.server_port = 1024
    self.utils_port  = 2048
    self.server_addr = 'ecelinux-01.ece.cornell.edu'

    self.superusers  = [ 'ka429' ]

  def getSU( self ):
    return self.superusers
