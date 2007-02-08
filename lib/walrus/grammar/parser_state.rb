# Copyright 2007 Wincent Colaiuta
# $Id$

require 'walrus/grammar/additions/array'
require 'walrus/grammar/additions/string'

module Walrus
  class Grammar
    
    # Simple class for maintaining state during a parse operation.
    # This class could potentially become useful if I ever implement a memoizing packrat parser.
    class ParserState
      
      # Returns the remainder (the unparsed portion) of the string. Will return an empty string if already at the end of the string.
      attr_reader :remainder
      
      # Returns the number of results accumulated so far.
      attr_reader :count
      
      # Returns the number of characters scanned so far (including skipped characters).
      attr_reader :length
      
      # Raises an ArgumentError if string is nil.
      def initialize(string)
        raise ArgumentError if string.nil?
        self.base_string  = string
        @results          = []              # for accumulating results
        @skipped          = []              # for accumulating skipped text
        @length           = 0               # for counting number of characters parsed so far
        @count            = 0               # for counting number of results parsed so far
        @remainder        = @base_string
      end
      
      # The parsed method is used to inform the receiver of a successful parsing event.
      # Note that substring need not actually be a String but it must respond to "to_s".
      # For example, an Array such as ['foo', 'bar'] is an acceptable input because invoking "to_s" on it returns 'foobar'.
      # As a convenience returns the remainder.
      # Raises an ArgumentError if substring is nil.
      def parsed(substring)
        raise ArgumentError if substring.nil?
        @results << substring
        @count += 1
        @length += substring.to_s.length
        @remainder = @base_string.chars[@length..-1].join # use chars method here to correctly support multi-byte characters
      end
      
      # The skipped method is used to inform the receiver of a successful parsing event where the parsed substring should be consumed but not included in the accumulated results.
      # In all other respects this method behaves exactly like the parsed method.
      def skipped(substring)
        raise ArgumentError if substring.nil?
        @skipped << substring
        @length += substring.to_s.length
        @remainder = @base_string.chars[@length..-1].join # use chars method here to correctly support multi-byte characters
      end
      
      # Returns the results accumulated so far.
      # Returns an empty array if no results have been accumulated.
      # Returns a single object if only one result has been accumulated. (NOTE: is this consistent?)
      # Returns an array of objects if multiple results have been accumulated.
      def results
        if @results.length == 1
          results = @results[0]
        else
          results = @results
        end
                
        # evidently, "results" must have an "omitted" accessor (Array, String, MatchDataWrapper all should)
        results.omitted = self.omitted if not results.nil?
        results
      end
      
      # Returns string representation of the results.
      def to_s
        self.results.to_s
      end
      
      # Returns the token or tokens that have been skipped so far.
      def omitted
        if @skipped.length == 1
          @skipped[0]
        else
          @skipped
        end
      end
      
      # TODO: possibly implement "undo/rollback" and "reset" methods
      # if I implement "undo" will probbaly do it as a stack
      # will have the option of implementing "redo" as well but I'd only do that if I could think of a use for it
      
    private
      
      def base_string=(string)
        @base_string = (string.clone rescue string)
      end
      
    end # class ParserState
    
  end # class Grammar
end # module Walrus

