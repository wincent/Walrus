# Copyright 2007-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'walrus/grammar'

module Walrus
  class Grammar
    # "The #echo directive is used to echo the output from expressions that
    # can't be written as simple $placeholders."
    # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/output.echo.html
    #
    # Convenient alternative short syntax for the #echo directive, similar to
    # ERB (http://www.ruby-doc.org/stdlib/libdoc/erb/rdoc/):
    #
    #   #= expression(s) #
    #
    # Is a shortcut equivalent to:
    #
    #   #echo expression(s) #
    #
    # This is similar to the ERB syntax, but even more concise:
    #
    #   <%= expression(s) =>
    #
    # See also the #silent directive, which also has a shortcut syntax.
    #
    class EchoDirective < Directive
      def compile options = {}
        if @expression.respond_to? :each
          expression = @expression
        else
          expression = [@expression]
        end

        # TODO: potentially include line, col and file name info in the
        # comments generated by the compiler

        compiled = "accumulate(instance_eval {\n" +
          expression.map { |expr| "  #{expr.compile}\n"}.join +
          "}) # Echo directive\n"
        compiled
      end
    end # class EchoDirective
  end # class Grammar
end # Walrus
