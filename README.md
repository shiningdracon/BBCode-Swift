# BBCode-Swift
A BBCode parser writing in swift.
Not like other regular expression BBCode libraries, this is a real parser.

## EBNF
     <document> ::= <element> | <document> <element>
     <element> ::= <tag> | <content>
     <tag> ::= <opening_tag_1> | <opening_tag> <content> <closing_tag>
     <opening_tag> ::= <opening_tag_1> | <opening_tag_2>
     <opening_tag_1> ::= <tag_prefix> <tag_end>
     <opening_tag_2> ::= <tag_prefix> '=' <attr> <tag_end>
     <tag_prefix> ::= <tag_start> <tag_name>
     <tag_start> ::= '['
     <tag_end> ::= ']'
     <attr> ::= <character> | <attr> <character>
     <closing_tag> ::= <tag_start> '/' <tag_name> <tag_end>
     <tag_name> ::= <character_non-key> | <tag_name> <character_non-key_2>
     <content> ::= <character> | <content> <character>
     <character> ::= unicode
     <character_non-key> ::= unicode not including '[', '=', ']', '/'
     <character_non-key_2> ::= <character_non-key> | '/'

