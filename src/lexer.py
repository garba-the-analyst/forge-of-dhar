#!/usr/bin/env python3
import re
from enum import Enum, auto
from dataclasses import dataclass

class TokenType(Enum):
    KEYWORD = auto()       # fn, let, return, syscall, if, loop
    IDENTIFIER = auto()    # variable and function names
    NUMBER = auto()        # Integer literals
    STRING = auto()        # "Text payloads"
    SYMBOL = auto()        # { } ( ) : ; = ,
    EOF = auto()           # End of file

@dataclass
class Token:
    type: TokenType
    value: str
    line: int
    column: int

class Lexer:
    # Core Dhar language reserved keywords
    KEYWORDS = {"fn", "let", "return", "syscall", "if", "loop", "const"}
    
    # Regex patterns for token mapping
    TOKEN_SPECIFICATION = [
        ("NUMBER",    r"\d+"),                           # Integer
        ("STRING",    r'"[^"]*"'),                       # String literal
        ("IDENTIFIER",r"[a-zA-Z_][a-zA-Z0-9_]*"),        # Identifiers
        ("SYMBOL",    r"[{}():;=,]"),                    # Structural symbols
        ("WHITESPACE",r"[ \t]+"),                        # Spaces and tabs
        ("NEWLINE",   r"\n"),                            # Line endings
        ("COMMENT",   r"//.*"),                          # Line comments
        ("MISMATCH",  r"."),                             # Any other character
    ]
    
    def __init__(self, source_code: str):
        self.source_code = source_code
        self.tokens = []
        self.regex = re.compile("|".join(f"(?P<{pair[0]}>{pair[1]})" for pair in self.TOKEN_SPECIFICATION))

    def tokenize(self) -> list[Token]:
        line_num = 1
        line_start = 0
        
        for match in self.regex.finditer(self.source_code):
            kind = match.lastgroup
            value = match.group()
            column = match.start() - line_start
            
            if kind == "NUMBER":
                self.tokens.append(Token(TokenType.NUMBER, value, line_num, column))
            elif kind == "STRING":
                # Strip the surrounding quotes for the AST
                self.tokens.append(Token(TokenType.STRING, value[1:-1], line_num, column))
            elif kind == "IDENTIFIER":
                token_type = TokenType.KEYWORD if value in self.KEYWORDS else TokenType.IDENTIFIER
                self.tokens.append(Token(token_type, value, line_num, column))
            elif kind == "SYMBOL":
                self.tokens.append(Token(TokenType.SYMBOL, value, line_num, column))
            elif kind == "NEWLINE":
                line_start = match.end()
                line_num += 1
            elif kind in ("WHITESPACE", "COMMENT"):
                continue
            elif kind == "MISMATCH":
                raise SyntaxError(f"Unexpected token '{value}' at line {line_num}, column {column}")
                
        self.tokens.append(Token(TokenType.EOF, "", line_num, 0))
        return self.tokens

if __name__ == "__main__":
    # Test suite for the Dhar tokenizer
    sample_code = """
    // Dhar standard system call test
    fn main() {
        let msg = "Hello, Architecture!";
        syscall(1, 1, msg, 20);
        return 0;
    }
    """
    lexer = Lexer(sample_code)
    for token in lexer.tokenize():
        print(f"{token.type.name:<12} | {token.value:<20} | Line: {token.line}")