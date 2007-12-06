require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'

begin
  require 'xml_simple'
rescue LoadError
  require 'rubygems'
  require 'active_support'
  begin
  require 'xml_simple'
  rescue LoadError
    require 'xmlsimple'
  end
end


# A very simple REST client, best explained by example:
#
#   # Retrieve a Kitten and print its name and colour
#   kitten = Restr.get('http://example.com/kittens/1.xml')
#   puts kitten['name']
#   puts kitten['colour']
#
#   # Create a Kitten
#   kitten = Restr.post('http://example.com/kittens.xml', 
#     :name => 'batman', :colour => 'black')
#
#   # Update a Kitten
#   kitten = Restr.put('http://example.com/kittens/1.xml', 
#     :age => '6 months')
#
#   # Delete a Kitten :(
#   kitten = Restr.delete('http://example.com/kittens/1.xml')
#
#   # Retrieve a list of Kittens
#   kittens = Restr.get('http://example.com/kittens.xml')
#
# When the response to a Restr request has content type 'text/xml', the
# response body will be parsed from XML into a nested Hash (using XmlSimple 
# -- see http://xml-simple.rubyforge.org/). Otherwise the response is  
# returned untouched, as a String.
#
# If the remote REST resource requires authentication (Restr only supports
# HTTP Basic authentication, for now):
#
#   Restr.get('http://example.com/kittens/1.xml, {}, 
#     {:username => 'foo', :password => 'bar'})
#
class Restr
  @@log = nil
  
  def self.logger=(logger)
    @@log = logger
    @@log.progname = self.name
  end
  
  def self.method_missing(method, *args)
    self.do(method, args[0], args[1] || {}, args[2])
  end
  
  def self.do(method, url, params = {}, auth = nil)
    uri = URI.parse(url)
    params = {} unless params
      
    method_mod = method.to_s.downcase.capitalize
    unless Net::HTTP.const_defined?(method_mod)
      raise InvalidRequestMethod, 
        "Callback method #{method.inspect} is not a valid HTTP request method."
    end
    
    if method_mod == 'Get'
      q = params.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join("&")
      if uri.query
        uri.query += "&#{q}"
      else
        uri.query = q
      end
    end
    
    req = Net::HTTP.const_get(method_mod).new(uri.request_uri)
    
    
    if auth
      raise ArgumentError, 
        "The `auth` parameter must be a Hash with a :username and :password value." unless 
        auth.kind_of? Hash
      req.basic_auth auth[:username] || auth['username'], auth[:password] || auth['password']
    end
    
    unless method_mod == 'Get'
      req.set_form_data(params, ';')
    end
    
    @@log.debug("Sending #{method.inspect} request to #{url.inspect} with data #{params.inspect}"+
        (auth ? " with authentication" : "")+".") if @@log
 
    client = Net::HTTP.new(uri.host, uri.port)
    client.use_ssl = (uri.scheme == 'https')
    res = client.start do |http|
      http.request(req)
    end
    
    case res
    when Net::HTTPSuccess
      if res.content_type == 'text/xml'
        @@log.debug("Got XML response.") if @@log
        return XmlSimple.xml_in_string(res.body,
          'forcearray'   => false,
          'keeproot'     => false
        )
      else
        @@log.debug("Got #{res.content_type.inspect} response.") if @@log
        return res.body
      end
    else
      $LAST_ERROR_BODY = res.body # FIXME: this is dumb
      @@log.error("Got error resposne '#{res.message}(#{res.code})': #{$LAST_ERROR_BODY}") if @@log
      res.error!      
    end
  end
  
  class InvalidRequestMethod < Exception
  end
end