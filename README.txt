= Reststop

<b>Reststop makes it easy to write RESTful[http://en.wikipedia.org/wiki/Representational_State_Transfer] 
applications in Camping[http://camping.rubyforge.org/files/README.html].</b>

For info and downloads please see http://rubyforge.org/projects/reststop


*Author*::    Matt Zukowski (matt at roughest dot net)
*Copyright*:: Copyright (c) 2007 Urbacon Ltd.
*License*::   GNU Lesser General Public License Version 3


For an example of a complete Reststop-based Camping app, have a look at 
http://reststop.rubyforge.org/svn/trunk/examples/blog.rb

Reststop essentially gives you three things:

<b>1. Camping controllers that respond to the standard REST verbs:</b>

* create (POST)
* read (GET)
* update (PUT)
* destroy (DELETE)
* list (GET)

Custom actions are also possible. See the Camping::Controllers#REST method documentation for usage info.

<b>2. Camping views grouped by output format:</b>

Your views module:

  module Foobar::Views
    module HTML
      def foo
        html do
          p "Hello World"
        end
      end
    end
    module XML
      def foo
        tag!('foo')
          "Hello World"
        end
      end
    end
  end

Your render call:

  render(:foo, :XML)
  
See the Camping#render method documentation for usage info.

<b>3. Nice URLs to bring it all together:</b>

For example a list of kittens in the default format (HTML) is available at:

  /kittens

The list, in RSS format:

  /kittens.rss
  
Kitten with id 1, in XML format:
  
  /kittens/1.xml
  
Using custom action 'meow' on kitten with id 1:

  /kittens/1/meow

In other words, say you have a "kittens" resource; you can make a GET
request to http://yourapp.com/kittens.xml and get a list of kittens
through your Kittens controller's <tt>list</tt>, formatted using your
<tt>XML</tt> view module. 


<b>BONUS: A simple REST client</b>

Reststop also comes with a very simple REST client called Restr.
Restr is basically a wrapper around Ruby's Net::HTTP, offering
a more RESTfully meaningful interface.

See the Restr documentation for more info, but here's a simple
example of RESTful interaction with Restr:

  require 'restr'
  kitten = Restr.get('http://example.com/kittens/1.xml')
  puts kitten['name']
  puts kitten['colour']
  
  kitten['colour'] = 'black'
  kitten = Restr.put('http://example.com/kittens/1.xml', kitten)


----

Reststop is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published 
by the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Reststop is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.