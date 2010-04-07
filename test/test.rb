#	Prerequisites:
#		1) 	gem install xml-simple
#		2)		gem install restr

gem 'xml-simple'
gem 'restr'
require 'restr'

logger = Logger.new('restr.log')
logger.level = Logger::DEBUG
Restr.logger = logger

u0 =  "http://localhost:3301/sessions.xml"
o = { :username=>'admin', :password=>'camping'}
p0=Restr.post(u0,o)

u1 = "http://localhost:3301/posts/1.xml"
p = Restr.get(u1,o)

# Modify the title
p['title']='HOT off the presses: ' + p['title']

# Update the resource
p2=Restr.put(u1,p,o)

u3="http://localhost:3301/posts.xml"
p3={ :title=>'Brand new REST-issued post', :body=>'RESTstop makes it happen!!!'} 
p4=Restr.post(u2,p3)

u3="http://localhost:3301/posts/4.xml"
p5=Restr.delete(u3)