= Reststop

<i>Copyright 2007 Urbacon Ltd.</i>

For info and downloads please see:

  http://rubyforge.org/projects/reststop/

You can contact the author at:

  matt at roughest dot net
  

<b>Reststop makes it easy to write RESTful[http://en.wikipedia.org/wiki/Representational_State_Transfer] 
applications in Camping[http://camping.rubyforge.org/files/README.html].</b>

Reststop essentially gives you two things:

<b>Camping controllers that respond to the standard REST verbs:</b>

* create (POST)
* read (GET)
* update (PUT)
* destroy (DELETE)
* list (GET)

See the Camping::Controllers#REST method documentation for usage info.

<b>Camping views grouped by output format:</b>

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
  
See the render() method documentation for usage info.


----

Reststop is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Reststop is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.