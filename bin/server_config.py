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
    self.utils_port  = 2048

    # Superusers
    self.superusers  = [ 'pi57', 'ka429' ]

    # Token for TravisCI
    self.travis_token = 'ocYw4zq55hiuyYvJJcBV'

  def getSU( self ):
    return self.superusers
