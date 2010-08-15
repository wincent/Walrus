# Copyright 2007-2010 Wincent Colaiuta
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'walrat'

module Walrat
  # A SymbolParslet allows for evaluation of a parslet to be deferred until
  # runtime (or parse time, to be more precise).
  class SymbolParslet < Parslet
    attr_reader :hash

    def initialize symbol
      raise ArgumentError if symbol.nil?
      @symbol = symbol

      # fixed offset to avoid collisions with @parseable objects
      @hash = @symbol.hash + 20
    end

    # SymbolParslets don't actually know what Grammar they are associated with
    # at the time of their definition. They expect the Grammar to be passed in
    # with the options hash under the ":grammar" key.
    # Raises if string is nil, or if the options hash does not include a
    # :grammar key.
    def parse string, options = {}
      raise ArgumentError if string.nil?
      raise ArgumentError unless options.has_key?(:grammar)
      grammar = options[:grammar]
      augmented_options = options.clone
      augmented_options[:rule_name] = @symbol
      augmented_options[:skipping_override] = grammar.skipping_overrides[@symbol] if grammar.skipping_overrides.has_key?(@symbol)
      result = grammar.rules[@symbol].memoizing_parse(string, augmented_options)
      grammar.wrap(result, @symbol)
    end

    # We override the to_s method as it can make parsing error messages more
    # readable. Instead of messages like this:
    #
    #   predicate not satisfied (expected "#<Walrat::SymbolParslet:0x10cd504>")
    #   while parsing "hello world"
    #
    # We can print messages like this:
    #
    #   predicate not satisfied (expected "rule: end_of_input") while parsing
    #   "hello world"
    def to_s
      'rule: ' + @symbol.to_s
    end

    def ==(other)
      eql?(other)
    end

    def eql?(other)
      other.instance_of? SymbolParslet and other.symbol == @symbol
    end

  protected

    # For equality comparisons.
    attr_reader :symbol
  end # class SymbolParslet
end # module Walrat
