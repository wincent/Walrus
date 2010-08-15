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

require 'walrus'
require 'pathname'

module Walrus
  # The parser is currently quite slow, although perfectly usable.
  # The quickest route to optimizing it may be to replace it with a C parser
  # inside a Ruby extension, possibly generated using Ragel
  class Parser
    def parse string, options = {}
      Grammar.new.parse string, options
    end

    def compile string, options = {}
      @@compiler ||= Compiler.new
      parsed = []
      catch :AndPredicateSuccess do # catch here because empty files throw
        parsed = parse string, options
      end
      @@compiler.compile parsed, options
    end
  end # class Parser
end # module Walrus
