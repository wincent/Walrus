# Copyright 2007 Wincent Colaiuta
# $Id$

require 'walrus'

module Walrus
  class Grammar
    
    # Methods for embedding location information in objects returned (or exceptions raised) from parse methods.
    module LocationTracking
      
      attr_reader :source_text
      
      def source_text=(string)
        @source_text = string.to_s.clone
      rescue NoMethodError
        @source_text = string.to_s
      end
      
      # Sets @column_start to col.
      # Sets @column_start to 0 if passed nil (for ease of use, users of classes that mix-in this module don't have to worry about special casing nil values).
      def column_start=(col)
        @column_start = col.to_i
      rescue NoMethodError
        @column_start = 0
      end
      
      # Returns 0 if @column_start is nil (for ease of use, users of classes that mix-in this module don't have to worry about special casing nil values).
      def column_start
        @column_start || 0
      end
      
      # Sets @line_start to line.
      # Sets @line_start to 0 if passed nil (for ease of use, users of classes that mix-in this module don't have to worry about special casing nil values).
      def line_start=(line)
        @line_start = line.to_i
      rescue NoMethodError
        @line_start = 0
      end
      
      # Returns 0 if @line_start is nil (for ease of use, users of classes that mix-in this module don't have to worry about special casing nil values).
      def line_start
        @line_start || 0
      end
      
      # Convenience method for getting both line_start and column_start at once.
      def start
        [self.line_start, self.column_start]
      end
      
      # Convenience method for setting both line_start and column_start at once.
      def start=(array)
        raise ArgumentError if array.nil?
        raise ArgumentError if array.length != 2
        self.line_start    = array[0]
        self.column_start  = array[1]
      end
      
      def line_end=(line_end)
        @line_end = line_end.to_i
      rescue NoMethodError
        @line_end = 0
      end
      
      def line_end
        @line_end || 0
      end
      
      def column_end=(column_end)
        @column_end = column_end.to_i
      rescue NoMethodError
        @column_end = 0
      end
      
      def column_end
        @column_end || 0
      end
      
      # Convenience method for getting both line_end and column_end at once.
      def end
        [self.line_end, self.column_end]
      end
      
      # Convenience method for setting both line_end and column_end at once.
      def end=(array)
        raise ArgumentError if array.nil?
        raise ArgumentError if array.length != 2
        self.line_end   = array[0]
        self.column_end = array[1]
      end
      
      # Given another object that responds to column_end and line_end, returns true if the receiver is rightmost or equal.
      # If the other object is farther to the right returns false.
      def rightmost?(other)
        if self.line_end > other.line_end         : true
        elsif other.line_end > self.line_end      : false
        elsif self.column_end >= other.column_end : true
        else                                        false
        end
      end
      
    end # module LocationTracking
    
  end # class Grammar
end # module Walrus
