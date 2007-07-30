= Reststop

<i>Copyright 2007 Urbacon Ltd.</i>

For info and downloads please see:

  http://rubyforge.org/projects/reststop/

You can contact the author at:

  matt at roughest dot net
  

<b>Reststop makes it easy to write RESTful[http://en.wikipedia.org/wiki/Representational_State_Transfer]
applications in Camping[http://camping.rubyforge.org/files/README.html].</b>

Reststop essentially gives you two things:

=== Camping controllers that respond to the standard REST verbs:

  * create (POST)
  * read (GET)
  * update (PUT)
  * destroy (DELETE)
  * list (GET)

See the REST method documentation for usage info.

=== Camping views grouped by output format:

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