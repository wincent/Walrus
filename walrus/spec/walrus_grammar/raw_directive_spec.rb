# Copyright 2007 Wincent Colaiuta
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# in the accompanying file, "LICENSE.txt", for more details.
#
# $Id: raw_directive_spec.rb 192 2007-05-03 09:27:35Z wincent $

require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')
require 'walrus/parser' # ensure that WalrusGrammar is defined before continuing

module Walrus
  class WalrusGrammar
    
    class RawDirectiveAccumulator
      attr_reader :content
      def initialize
        @content = ''
      end
      def accumulate(string)
        @content << string
      end
    end
    
    describe 'compiling a RawDirective instance' do
      
      it 'should be able to round trip' do
        @accumulator  = RawDirectiveAccumulator.new
        @raw          = RawDirective.new('hello \'world\'\\... € #raw, $raw, \\raw')
        @accumulator.instance_eval(@raw.compile)
        @accumulator.content.should == 'hello \'world\'\\... € #raw, $raw, \\raw'
      end
      
    end
    
    describe 'producing a Document containing RawText' do
      
      before(:each) do
        @parser = Parser.new
      end
      
      it 'should be able to round trip' do
        
        # simple example
        raw = @parser.compile("#raw\nhello world\n#end", :class_name => :RawDirectiveSpecAlpha)
        self.class.class_eval(raw)
        self.class::Walrus::WalrusGrammar::RawDirectiveSpecAlpha.new.fill.should == "hello world\n"
        
        # containing single quotes
        raw = @parser.compile("#raw\nhello 'world'\n#end", :class_name => :RawDirectiveSpecBeta)
        self.class.class_eval(raw)
        self.class::Walrus::WalrusGrammar::RawDirectiveSpecBeta.new.fill.should == "hello 'world'\n"
        
        # containing a newline
        raw = @parser.compile("#raw\nhello\nworld\n#end", :class_name => :RawDirectiveSpecDelta)
        self.class.class_eval(raw)
        self.class::Walrus::WalrusGrammar::RawDirectiveSpecDelta.new.fill.should == "hello\nworld\n"
        
        # using a "here document"
        raw = @parser.compile("#raw <<HERE
hello world
literal #end with no effect
HERE", :class_name => :RawDirectiveSpecGamma)
        self.class.class_eval(raw)
        self.class::Walrus::WalrusGrammar::RawDirectiveSpecGamma.new.fill.should == "hello world\nliteral #end with no effect\n"
        
        # "here document", alternative syntax
        raw = @parser.compile("#raw <<-HERE
hello world
literal #end with no effect
        HERE", :class_name => :RawDirectiveSpecIota)
        self.class.class_eval(raw)
        self.class::Walrus::WalrusGrammar::RawDirectiveSpecIota.new.fill.should == "hello world\nliteral #end with no effect\n"
        
      end
      
    end
    
  end # class WalrusGrammar
end # module Walrus

