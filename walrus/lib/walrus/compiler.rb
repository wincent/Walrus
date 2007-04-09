# Copyright 2007 Wincent Colaiuta
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# in the accompanying file, "LICENSE.txt", for more details.
#
# $Id$

require 'walrus'
require 'pathname'

module Walrus
  class Compiler
    
    BODY_INDENT     = ' ' * 8
    OUTSIDE_INDENT  = ' ' * 6
    DEFAULT_CLASS   = 'DocumentSubclass'
    
    # The public compiler class serves as the interface with the outside world. For thread-safety and concurrency, an inner, private Instance class is spawned in order to perform the actual compilation.
    class Instance
      
      def initialize(options)        
        @class_name     = (options[:class_name] || DEFAULT_CLASS).to_s
        @template_body  = []  # will accumulate items for body, and joins them at the end of processing
        @outside_body   = []  # will accumulate items for outside of body, and joins them at the end of processing
      end
      
      def compile_subtree(subtree)
        template_body   = [] # local variable
        outside_body    = [] # local variable
        subtree = [subtree] unless subtree.respond_to? :each
        options = { :compiler_instance => self } # reset
        subtree.each do |element|          
          # def/block and include directives may return two items
          if element.kind_of? WalrusGrammar::DefDirective or element.kind_of? WalrusGrammar::IncludeDirective
            inner, outer = element.compile(options)
            outer.each { |line| outside_body << OUTSIDE_INDENT + line } if outer
            inner.each { |line| template_body << BODY_INDENT + line } if inner
          elsif element.instance_of? WalrusGrammar::ExtendsDirective  # defines superclass and automatically invoke #super (super) at the head of the template_body
            raise CompileError.new('#extends may be used only once per template') unless @extends_directive.nil?
            raise CompileError.new('illegal #extends (#import already used in this template)') unless @import_directive.nil?
            @extends_directive = element.compile(options)
          elsif element.instance_of? WalrusGrammar::ImportDirective   # defines superclass with no automatic invocation of #super on the template_body
            raise CompileError.new('#import may be used only once per template') unless @import_directive.nil?
            raise CompileError.new('illegal #import (#extends already used in this template)') unless @extends_directive.nil?
            @import_directive = element.compile(options)
          elsif element.kind_of? WalrusGrammar::Comment and element.column_start == 0  # special case if comment is only thing on input line
            template_body << BODY_INDENT + element.compile(options)
            options[:slurping] = true
            next
          else                                                    # everything else gets added to the template_body
            element.compile(options).each { |line| template_body << BODY_INDENT + line } # indent by 6 spaces
          end
          options = { :compiler_instance => self } # reset
        end
        [template_body, outside_body]
      end
      
      def compile(tree)
        inner, outer = compile_subtree(tree)
        @template_body.concat inner if inner
        @outside_body.concat outer if outer
        if @import_directive
          superclass_name = @import_directive.class_name
          require_line    = "require 'walrus/document'\n" + @import_directive.require_line
        elsif @extends_directive
          superclass_name = @extends_directive.class_name
          require_line    = "require 'walrus/document'\n" + @extends_directive.require_line
          @template_body.unshift BODY_INDENT + "super # (invoked automatically due to Extends directive)\n"
        else
          superclass_name = 'Document'
          require_line    = "require 'walrus/document'"
        end

        <<-RETURN
\#!/usr/bin/env ruby
\# Generated #{Time.new.to_s} by Walrus version #{VERSION}

begin
  require 'rubygems'
rescue LoadError
  # installing Walrus via RubyGems is recommended
  # otherwise Walrus must be installed in the RUBYLIB load path
end

#{require_line}

module Walrus

  class WalrusGrammar

    class #{@class_name} < #{superclass_name}

      def template_body

#{@template_body.join}
      end

#{@outside_body.join}    
      if __FILE__ == $0   # when run from the command line the default action is to call 'run'
        self.new.run
      else                # in other cases, evaluate 'fill' (if run inside an eval, will return filled content)
        self.new.fill
      end

    end \# #{@class_name}

  end \# WalrusGrammar

end \# Walrus

        RETURN
        
      end
      
    end
    
    # Walks the Abstract Syntax Tree, tree, that represents a parsed Walrus template.
    # Returns a String that defines a Document subclass corresponding to the compiled version of the tree.
    def compile(tree, options = {})
      Instance.new(options).compile(tree)
    end
    
  end # class Compiler
end # module Walrus

