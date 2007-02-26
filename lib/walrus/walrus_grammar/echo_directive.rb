# Copyright 2007 Wincent Colaiuta
# $Id$

require 'walrus/parser.rb' # make sure that RawText class has been defined prior to extending it

module Walrus
  class WalrusGrammar
    
    class EchoDirective
      
      def compile(options = {})
        
        if @expression.respond_to? :each
          expression = @expression
        else
          expression = [@expression]
        end
        
        # TODO: potentially include line, col and file name info in the comments generated by the compiler
        
        compiled  = ''
        first     = true
        expression.each do |expr| 
          if first
            compiled << "accumulate(instance_eval { %s }) # Echo directive\n" % expr.compile
            first = false
          else
            compiled << "accumulate(instance_eval { %s }) # Echo directive (continued)\n" % expr.compile
          end
        end
        compiled
        
      end
      
    end # class EchoDirective
    
  end # class WalrusGrammar
end # Walrus

