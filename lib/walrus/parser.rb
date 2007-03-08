# Copyright 2007 Wincent Colaiuta
# $Id$

require 'walrus'

module Walrus
  
  class Parser
    
    def parse(string)
      @@grammar.parse(string)
    end
    
    def compile(string, options = {})
      @@compiler ||= Compiler.new
      parsed = []
      catch :AndPredicateSuccess do # catch here because an empty file will throw
        parsed = parse string
      end
      @@compiler.compile parsed, options
    end
    
    @@grammar ||= Grammar.subclass('WalrusGrammar') do
      
      starting_symbol :template
      
      skipping        :whitespace_or_newlines
      
      rule            :whitespace_or_newlines,              /\s+/
      
      # only spaces and tabs, not newlines
      rule            :whitespace,                          /[ \t\v]+/
      rule            :newline,                             /(\r\n|\r|\n)/
      
      # optional whitespace (tabs and spaces only) followed by a backslash/newline (note: this is not escape-aware)
      rule            :line_continuation,                   /[ \t\v]*\\\n/
      rule            :end_of_input,                        /\z/
      
      rule            :template,                            :template_element.zero_or_more & :end_of_input.and?
      rule            :template_element,                    :raw_text | :comment | :multiline_comment | :directive | :placeholder |:escape_sequence
      
      # anything at all other than the three characters which have special meaning in Walrus: $, \ and #
      rule            :raw_text,                            /[^\$\\#]+/
      production      :raw_text.build(:node)
      
      node            :literal
      
      rule            :string_literal,                      :single_quoted_string_literal | :double_quoted_string_literal
      skipping        :string_literal, nil
      node            :string_literal, :literal
      
      rule            :single_quoted_string_literal,        "'".skip & :single_quoted_string_content.optional & "'".skip
      production      :single_quoted_string_literal.build(:string_literal)
      rule            :single_quoted_string_content,        /(\\(?!').|\\'|[^'\\]+)+/
      rule            :double_quoted_string_literal,        '"'.skip & :double_quoted_string_content.optional & '"'.skip
      production      :double_quoted_string_literal.build(:string_literal)
      rule            :double_quoted_string_content,        /(\\(?!").|\\"|[^"\\]+)+/
      
      # TODO: support 1_000_000 syntax for numeric_literals
      rule            :numeric_literal,                     /\d+\.\d+|\d+(?!\.)/
      production      :numeric_literal.build(:literal)
      rule            :identifier,                          /[a-z_][a-zA-Z0-9_]*/
      production      :identifier.build(:literal)
      rule            :constant,                            /[A-Z][a-zA-Z0-9_]*/
      production      :constant.build(:literal)
      rule            :symbol_literal,                      /:[a-zA-Z_][a-zA-Z0-9_]*/
      production      :symbol_literal.build(:literal)
      
      rule            :escape_sequence,                     '\\'.skip & /[\$\\#]/
      production      :escape_sequence.build(:node)
      
      # Would be nice to make it that if a comment is the only thing on a line then it consumes its trailing newline as well; but this would require us to look behind where we are in the input (because /^##/ will always succeed wherever /##/ succeeds, and it doesn't handle the more complex cases, like where a comment is preceeded by a directive); this is therfore a task for the compiler, not the parser.
      rule            :comment,                             '##'.skip & /.*$/
      production      :comment.build(:node)
      
      # nested multiline comments
      rule            :multiline_comment,                   '#*'.skip & :comment_content.zero_or_more('') & '*#'.skip
      skipping        :multiline_comment, nil
      production      :multiline_comment.build(:comment, :content)
      
      # human-language version of the regex: "any run of characters other than # or *, any # not followed by another # or a *, or any * not followed by a #"
      rule            :comment_content,                     (:comment & :newline.skip) | :multiline_comment | /([^*#]+|#(?!#|\*)|\*(?!#))+/
      
      rule            :directive,                           :block_directive    |
                                                            :def_directive      |
                                                            :echo_directive     |
                                                            :extends_directive  |
                                                            :import_directive   |
                                                            :include_directive  |
                                                            :raw_directive      |
                                                            :ruby_directive     |
                                                            :set_directive      |
                                                            :silent_directive   |
                                                            :slurp_directive    |
                                                            :super_directive
      
      node            :directive
      
      # directives may span multiple lines if and only if the last character on the line is a backslash \
      skipping        :directive,                           :whitespace | :line_continuation
      
      # "Directive tags can be closed explicitly with #, or implicitly with the end of the line"
      # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/language.directives.closures.html
      # This means that to follow a directive by a comment on the same line you must explicitly close the directive first (otherwise the grammar would be ambiguous).
      # Note that "skipping" the end_of_input here is harmless as it isn't actually consumed.
      rule            :directive_end,                       ( /#/ | :newline | :end_of_input ).skip
      
      rule            :block_directive,                     '#block'.skip & :identifier & :def_parameter_list.optional([]) & :directive_end &
                                                            :template_element.zero_or_more([]) &
                                                            '#end'.skip & :directive_end
      
      rule            :def_directive,                       '#def'.skip & :identifier & :def_parameter_list.optional([]) & :directive_end &
                                                            :template_element.zero_or_more([]) &
                                                            '#end'.skip & :directive_end
      
      production      :def_directive.build(:directive, :identifier, :params, :content)        # superclass (DefDirective) must be created
      production      :block_directive.build(:def_directive, :identifier, :params, :content)  # before the subclass (BlockDirective)
      
      # "The #echo directive is used to echo the output from expressions that can't be written as simple $placeholders."
      # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/output.echo.html
      rule            :echo_directive,                      '#echo'.skip & :ruby_expression_list & :directive_end
      production      :echo_directive.build(:directive, :expression)
      
      rule            :extends_directive,                   '#extends'.skip & :string_literal & :directive_end
      rule            :import_directive,                    '#import'.skip & :string_literal & :directive_end
      production      :import_directive.build(:directive, :class_name)          # superclass (ImportDirective) must be created
      production      :extends_directive.build(:import_directive, :class_name)  # before the subclass (ExtendsDirective)
      
      rule            :include_directive,                   '#include'.skip & :string_literal & :directive_end
      production      :include_directive.build(:directive, :file_name)
      
      # "Any section of a template definition that is inside a #raw ... #end raw tag pair will be printed verbatim without any parsing of $placeholders or other directives."
      # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/output.raw.html
      # Unlike Cheetah, Walrus uses a bare "#end" marker and not an "#end raw" to mark the end of the raw block.
      # The presence of a literal #end within a raw block is made possible by using a "here doc"-style delimiter:
      #
      # #raw <<END_MARKER
      #     content goes here
      # END_MARKER
      #
      # Here the opening "END_MARKER" must be the last thing on the line (trailing whitespace up to and including the newline is allowed but it is not considered to be part of the quoted text). The final "END_MARKER" must be the very first and last thing on the line, or it will not be considered to be an end marker at all and will be considered part of the quoted text. The newline immediately prior to the end marker is included in the quoted text.
      #
      # Or, if the end marker is to be indented:
      #
      # #raw <<-END_MARKER
      #     content
      #      END_MARKER
      #
      # Here "END_MARKER" may be preceeded by whitespace (and whitespace only) but it must be the last thing on the line. The preceding whitespace is not considered to be part of the quoted text.
      rule            :raw_directive,                       '#raw'.skip & ((:directive_end & /([^#]+|#(?!end)+)*/ & '#end'.skip & :directive_end) | :here_document)
      production      :raw_directive.build(:directive, :content)
      
      # In order to parse "here documents" we adopt a model similar to the one proposed in this message to the ANTLR interest list:
      # http://www.antlr.org:8080/pipermail/antlr-interest/2005-September/013673.html
      rule            :here_document,                       lambda { |string, options|
        
        # for the time-being, not sure if there is much benefit in calling memoizing_parse here
        state     = Grammar::ParserState.new(string, options)
        parsed    = /<<(-?)([a-zA-Z0-9_]+)[ \t\v]*\n/.to_parseable.parse(state.remainder, state.options)
        state.skipped(parsed)
        marker    = parsed.match_data
        indenting = (marker[1] == '') ? false : true
        
        if indenting                                                # whitespace allowed before end marker
          end_marker  = /^[ \t\v]*#{marker[2]}[ \t\v]*(\n|\z)/.to_parseable # will eat trailing newline
        else                                                        # no whitespace allowed before end marker
          end_marker  = /^#{marker[2]}[ \t\v]*(\n|\z)/.to_parseable         # will eat trailing newline
        end
        
        line = /^.*\n/.to_parseable # for gobbling a line
        
        while true do
          begin
            skipped = end_marker.parse(state.remainder, state.options)
            state.skipped(skipped)          # found end marker, skip it
            break                           # all done
          rescue Grammar::ParseError        # didn't find end marker yet, consume a line
            parsed = line.parse(state.remainder, state.options)
            state.parsed(parsed)
          end
        end
        
        # caller will want a String, not an Array
        results         = state.results
        document        = Grammar::StringResult.new(results.to_s)
        document.start  = results.start
        document.end    = results.end
        document
      }
      
      rule            :ruby_directive,                      '#ruby'.skip & ((:directive_end & /([^#]+|#(?!end)+)*/ & '#end'.skip & :directive_end) | :here_document)
      production      :ruby_directive.build(:directive, :content)
      
      # Unlike a normal Ruby assignement expression, the lvalue of a "#set" directive is an identifier preceded by a dollar sign.
      rule            :set_directive,                       '#set'.skip & /\$(?![ \r\n\t\v])/.skip & :placeholder_name & '='.skip & (:addition_expression | :unary_expression) & :directive_end
      production      :set_directive.build(:directive, :placeholder, :expression)
      
      # "#silent is the opposite of #echo. It executes an expression but discards the output."
      # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/output.silent.html
      rule            :silent_directive,                    '#silent'.skip & :ruby_expression_list & :directive_end
      production      :silent_directive.build(:directive, :expression)
      
      # Accept multiple expressions separated by a semi-colon.
      rule            :ruby_expression_list,                :ruby_expression >> (';'.skip & :ruby_expression ).zero_or_more
      
      # "The #slurp directive eats up the trailing newline on the line it appears in, joining the following line onto the current line."
      # http://www.cheetahtemplate.org/docs/users_guide_html_multipage/output.slurp.html
      # The "slurp" directive must be the last thing on the line (not followed by a comment or directive end marker)
      rule            :slurp_directive,                     '#slurp' & :whitespace.optional.skip & :newline.skip
      production      :slurp_directive.build(:directive)
      
      rule            :super_directive,                     :super_with_parentheses | :super_without_parentheses
      node            :super_directive
      rule            :super_with_parentheses,              '#super'.skip & :parameter_list.optional & :directive_end
      production      :super_with_parentheses.build(:super_directive, :params)
      rule            :super_without_parentheses,           '#super'.skip & :parameter_list_without_parentheses & :directive_end
      production      :super_without_parentheses.build(:super_directive, :params)
      
      # The "def_parameter_list" is a special case of parameter list which disallows interpolated placeholders.
      rule            :def_parameter_list,                  '('.skip & ( :def_parameter >> ( ','.skip & :def_parameter ).zero_or_more ).optional & ')'.skip
      rule            :def_parameter,                       :assignment_expression | :identifier
      
      rule            :parameter_list,                      '('.skip & ( :parameter >> ( ','.skip & :parameter ).zero_or_more ).optional & ')'.skip
      rule            :parameter_list_without_parentheses,  :parameter >> ( ','.skip & :parameter ).zero_or_more
      rule            :parameter,                           :placeholder | :ruby_expression
      
      # placeholders may be in long form (${foo}) or short form ($foo)
      rule            :placeholder,                         :long_placeholder | :short_placeholder
      node            :placeholder
      
      # No whitespace allowed between the "$" and the opening "{"
      rule            :long_placeholder,                    '${'.skip & :placeholder_name & :placeholder_parameters.optional([]) & '}'.skip
      production      :long_placeholder.build(:placeholder, :name, :params)
      
      # No whitespace allowed between the "$" and the placeholder_name
      rule            :short_placeholder,                   /\$(?![ \r\n\t\v])/.skip & :placeholder_name & :placeholder_parameters.optional([])
      production      :short_placeholder.build(:placeholder, :name, :params)
      
      rule            :placeholder_name,                    :identifier
      rule            :placeholder_parameters,              '('.skip & (:placeholder_parameter >> (','.skip & :placeholder_parameter).zero_or_more).optional & ')'.skip
      rule            :placeholder_parameter,               :placeholder | :ruby_expression
      
      # simplified Ruby subset 
      rule            :ruby_expression,                     :unary_expression | :assignment_expression | :addition_expression
      node            :ruby_expression
      
      rule            :literal_expression,                  :string_literal     |
                                                            :numeric_literal    |
                                                            :array_literal      |
                                                            :hash_literal       |
                                                            :lvalue             |
                                                            :symbol_literal
      rule            :unary_expression,                    :literal_expression | :message_expression
      
      rule            :lvalue,                              :class_variable | :instance_variable | :identifier | :constant
      
      rule            :array_literal,                       '['.skip & ( :ruby_expression >> (','.skip & :ruby_expression ).zero_or_more ).optional & ']'.skip
      production      :array_literal.build(:ruby_expression, :elements)
      
      rule            :hash_literal,                        '{'.skip & ( :hash_assignment >> (','.skip & :hash_assignment ).zero_or_more ).optional & '}'.skip
      production      :hash_literal.build(:ruby_expression, :pairs)
      
      rule            :hash_assignment,                     :unary_expression & '=>'.skip & (:unary_expression | :addition_expression)
      production      :hash_assignment.build(:ruby_expression, :lvalue, :expression)
      
      rule            :assignment_expression,               :lvalue & '='.skip & (:addition_expression | :unary_expression)
      production      :assignment_expression.build(:ruby_expression, :lvalue, :expression)
      
      rule            :addition_expression,                 :unary_expression & '+'.skip & (:addition_expression | :unary_expression)
      production      :addition_expression.build(:ruby_expression, :left, :right)
      
      rule            :message_expression,                  :literal_expression & '.'.skip & :method_expression
      production      :message_expression.build(:ruby_expression, :target, :message)
      
      rule            :method_expression,                   :method_with_parentheses | :method_without_parentheses
      node            :method_expression, :ruby_expression
      
      rule            :method_with_parentheses,             :identifier & :method_parameter_list.optional([])
      production      :method_with_parentheses.build(:method_expression, :name, :params)
      rule            :method_without_parentheses,          :identifier & :method_parameter_list_without_parentheses
      production      :method_without_parentheses.build(:method_expression, :name, :params)
      
      rule            :method_parameter_list,               '('.skip & ( :method_parameter >> ( ','.skip & :method_parameter ).zero_or_more ).optional & ')'.skip
      rule            :method_parameter,                    :ruby_expression
      rule            :method_parameter_list_without_parentheses, :method_parameter >> ( ','.skip & :method_parameter ).zero_or_more
      
      rule            :class_variable,                      '@@'.skip & :identifier
      skipping        :class_variable, nil
      production      :class_variable.build(:ruby_expression)
      
      rule            :instance_variable,                   '@'.skip & :identifier
      skipping        :instance_variable, nil
      production      :instance_variable.build(:ruby_expression)
      
      # TODO: regexp literal expression
      
      # Ruby + allowing placeholders for unary expressions
      rule            :extended_ruby_expression,            :extended_unary_expression | :ruby_expression
      node            :extended_ruby_expression
      
      rule            :extended_unary_expression,           :placeholder | :unary_expression
      
      # only after defining the grammar is it safe to extend the classes dynamically created during the grammar definition
      require 'walrus/walrus_grammar/assignment_expression'
      require 'walrus/walrus_grammar/block_directive'
      require 'walrus/walrus_grammar/comment'
      require 'walrus/walrus_grammar/def_directive'
      require 'walrus/walrus_grammar/echo_directive'
      require 'walrus/walrus_grammar/escape_sequence'
      require 'walrus/walrus_grammar/import_directive'
      require 'walrus/walrus_grammar/instance_variable'
      require 'walrus/walrus_grammar/literal'
      require 'walrus/walrus_grammar/multiline_comment'
      require 'walrus/walrus_grammar/placeholder'
      require 'walrus/walrus_grammar/raw_directive'
      require 'walrus/walrus_grammar/raw_text'
      require 'walrus/walrus_grammar/ruby_directive'
      require 'walrus/walrus_grammar/set_directive'
      require 'walrus/walrus_grammar/silent_directive'
      require 'walrus/walrus_grammar/slurp_directive'
      require 'walrus/walrus_grammar/super_directive'
            
    end
    
  end # class Parser
  
end # module Walrus
