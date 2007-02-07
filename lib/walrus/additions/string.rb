# Copyright 2007 Wincent Colaiuta
# $Id$

# Additions to String class for Unicode support.
class String
  
  # Converts the receiver of the form "FooBar" to "foo_bar".
  # Concretely, the receiver is split into words, each word lowercased, and the words are joined together using a lower-case separator. "Words" are considered to be runs of characters starting with an initial capital letter (note that words may begin with consecutive capital letters), and numbers may mark the start or the end of a word.
  # Note that some information loss may be incurred; for example, "EOLToken" would be reduced to "eol_token".
  def to_require_name
    base = self.gsub(/([^A-Z_])([A-Z])/, '\1_\2')       # insert an underscore before any initial capital letters
    base.gsub!(/([A-Z])([A-Z])([^A-Z0-9_])/, '\1_\2\3') # consecutive capitals are words too, excluding any following capital that belongs to the next word
    base.gsub!(/([^0-9_])(\d)/, '\1_\2')                # numbers mark the start of a new word
    base.gsub!(/(\d)([^0-9_])/, '\1_\2')                # numbers also mark the end of a word
    base.downcase                                       # lowercase everything
  end
  
  # Converts the receiver of the form "foo_bar" to "FooBar".
  # Specifically, the receiver is split into pieces delimited by underscores, each component is then converted to captial case (the first letter is capitalized and the remaining letters are lowercased) and finally the components are joined.
  # Note that this method cannot recover information lost during a conversion using the require_name_from_classname method; for example, "EOL", when converted to "token", would be transformed back to "EolToken". Likewise, "Foo__bar" would be reduced to "foo__bar" and then in the reverse conversion would become "FooBar".
  def to_class_name
    self.split('_').collect { |component| component.capitalize}.join
  end
  
end # class String
