# Copyright 2007-2010 Wincent Colaiuta. All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'walrus/grammar'

module Walrus
  class Grammar
    # placeholders may be in long form (${foo}) or short form ($foo)
    # No whitespace allowed between the "$" and the opening "{"
    # No whitespace allowed between the "$" and the placeholder_name
    class Placeholder < Walrat::Node
      def compile options = {}
        if options[:nest_placeholders] == true
          method_name = "lookup_and_return_placeholder"     # placeholder nested inside another placeholder
        else
          method_name = "lookup_and_accumulate_placeholder" # placeholder used in a literal text stream
        end

        if @params == []
          "#{method_name}(#{@name.to_s.to_sym.inspect})\n"
        else
          options = options.clone
          options[:nest_placeholders] = true
          params      = (@params.kind_of? Array) ? @params : [@params]
          param_list  = params.map { |param| param.compile(options) }.join(', ').chomp
          "#{method_name}(#{@name.to_s.to_sym.inspect}, #{param_list})\n"
        end
      end
    end # class Placeholder
  end # class Grammar
end # Walrus
