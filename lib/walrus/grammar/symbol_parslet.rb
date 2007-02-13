# Copyright 2007 Wincent Colaiuta
# $Id$

module Walrus
  class Grammar
    
    autoload(:ContinuationWrapperException, 'walrus/grammar/continuation_wrapper_exception')
    
    require 'walrus/grammar/parslet'
    
    # A SymbolParslet allows for evaluation of a parslet to be deferred until runtime (or parse time, to be more precise).
    class SymbolParslet < Parslet
      
      def initialize(symbol)
        raise ArgumentError if symbol.nil?
        @symbol = symbol
      end
      
      # SymbolParslets don't actually know what Grammar they are associated with at the time of their definition. They expect the Grammar to be passed in with the options hash under the ":grammar" key.
      # Raises if string is nil, or if the options hash does not include a :grammar key.
      def parse(string, options = {})
        raise ArgumentError if string.nil?
        raise ArgumentError unless options.has_key?(:grammar)
        grammar = options[:grammar]
        augmented_options = options.clone
        augmented_options[:rule_name] = @symbol
        augmented_options[:skipping_override] = grammar.skipping_overrides[@symbol] if grammar.skipping_overrides.has_key?(@symbol)
        result = grammar.rules[@symbol].parse(string, augmented_options)
        grammar.wrap(result, @symbol)
      end
      
    end # class SymbolParslet
    
  end # class Grammar
end # module Walrus

