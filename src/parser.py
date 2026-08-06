#!/usr/bin/env python3
from lexer import TokenType, Token

# --- AST Node Definitions ---
class ASTNode: pass

class Program(ASTNode):
    def __init__(self, functions):
        self.functions = functions

class FunctionDef(ASTNode):
    def __init__(self, name, body):
        self.name = name
        self.body = body

class VariableDecl(ASTNode):
    def __init__(self, name, value):
        self.name = name
        self.value = value

class Syscall(ASTNode):
    def __init__(self, args):
        self.args = args

class ReturnStmt(ASTNode):
    def __init__(self, value):
        self.value = value

# --- The Parser ---
class Parser:
    def __init__(self, tokens: list[Token]):
        self.tokens = tokens
        self.pos = 0

    def current(self) -> Token:
        return self.tokens[self.pos]

    def consume(self, expected_type=None, expected_value=None) -> Token:
        token = self.current()
        if expected_type and token.type != expected_type:
            raise SyntaxError(f"Expected type {expected_type}, got {token.type} at line {token.line}")
        if expected_value and token.value != expected_value:
            raise SyntaxError(f"Expected '{expected_value}', got '{token.value}' at line {token.line}")
        self.pos += 1
        return token

    def parse(self) -> Program:
        functions = []
        while self.current().type != TokenType.EOF:
            functions.append(self.parse_function())
        return Program(functions)

    def parse_function(self) -> FunctionDef:
        self.consume(TokenType.KEYWORD, "fn")
        name = self.consume(TokenType.IDENTIFIER).value
        self.consume(TokenType.SYMBOL, "(")
        self.consume(TokenType.SYMBOL, ")")
        self.consume(TokenType.SYMBOL, "{")
        
        body = []
        while self.current().value != "}":
            token = self.current()
            if token.type == TokenType.KEYWORD:
                if token.value == "let":
                    body.append(self.parse_variable_decl())
                elif token.value == "syscall":
                    body.append(self.parse_syscall())
                elif token.value == "return":
                    body.append(self.parse_return())
                else:
                    raise SyntaxError(f"Unexpected keyword '{token.value}' at line {token.line}")
            else:
                raise SyntaxError(f"Unexpected token '{token.value}' at line {token.line}")
                
        self.consume(TokenType.SYMBOL, "}")
        return FunctionDef(name, body)

    def parse_variable_decl(self) -> VariableDecl:
        self.consume(TokenType.KEYWORD, "let")
        name = self.consume(TokenType.IDENTIFIER).value
        self.consume(TokenType.SYMBOL, "=")
        value = self.consume(TokenType.STRING).value
        self.consume(TokenType.SYMBOL, ";")
        return VariableDecl(name, value)

    def parse_syscall(self) -> Syscall:
        self.consume(TokenType.KEYWORD, "syscall")
        self.consume(TokenType.SYMBOL, "(")
        args = []
        while self.current().value != ")":
            if self.current().type in (TokenType.NUMBER, TokenType.IDENTIFIER, TokenType.STRING):
                args.append(self.current().value)
                self.consume()
            if self.current().value == ",":
                self.consume(TokenType.SYMBOL, ",")
        self.consume(TokenType.SYMBOL, ")")
        self.consume(TokenType.SYMBOL, ";")
        return Syscall(args)

    def parse_return(self) -> ReturnStmt:
        self.consume(TokenType.KEYWORD, "return")
        value = self.consume(TokenType.NUMBER).value
        self.consume(TokenType.SYMBOL, ";")
        return ReturnStmt(value)