# Copyright 2007 Wincent Colaiuta
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# in the accompanying file, "LICENSE.txt", for more details.
#
# $Id$

require 'walrus'

module Walrus
  class Grammar
    
    class ProcParslet < Parslet
      
      attr_reader :hash
      
      def initialize(proc)
        raise ArgumentError if proc.nil?
        self.expected_proc = proc
      end
      
      def parse(string, options = {})
        raise ArgumentError if string.nil?
        @expected_proc.call string, options
      end
      
      def eql?(other)
        other.instance_of? ProcParslet and other.expected_proc == @expected_proc
      end
      
    protected
      
      # For equality comparisons.
      attr_reader :expected_proc
      
    private
      
      def expected_proc=(proc)
        @expected_proc = ( proc.clone rescue proc )
        update_hash
      end
      
      def update_hash
        @hash = @expected_proc.hash + 105 # fixed offset to avoid collisions with @parseable objects
      end
      
    end # class ProcParslet
    
  end # class Grammar
end # module Walrus

