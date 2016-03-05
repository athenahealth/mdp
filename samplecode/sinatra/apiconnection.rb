require 'net/https'
require 'uri'

# Monkey patch to make Net::HTTP do proper SSL verification.
# Background reading: 
# http://stackoverflow.com/a/9238221
# http://blog.spiderlabs.com/2013/06/a-friday-afternoon-troubleshooting-ruby-openssl-its-a-trap.html
uri = URI.parse('https://api.athenahealth.com/')

$global_connection = Net::HTTP.new uri.host, uri.port
$global_connection.use_ssl = true

def $global_connection.proper_ssl_context!
  ssl_context = OpenSSL::SSL::SSLContext.new
  ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
  cert_store = OpenSSL::X509::Store.new
  cert_store.set_default_paths
  ssl_context.cert_store = cert_store
  @ssl_context = ssl_context
end

$global_connection.proper_ssl_context!
# End monkey patch

class ApiConnection
  def request *args
    $global_connection.request *args
  end
end
