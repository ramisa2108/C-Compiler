%option noyywrap
%x CHARSTATE
%x SINGLECOMMENTSTATE
%x MULTICOMMENTSTATE


%{
#include<iostream>
#include<fstream>
#include<sstream>
#include<string>
#include<vector>
#include "symbolTable.h"
#include "y.tab.h"

using namespace std;

void yyerror(string, bool f=false, bool m=false);
int line_count = 1;
int start_line = 0;
int string_comment_start_line = 0;
int error_count = 0;
int offset = 0;
string str;
string lexeme;

symbolInfo *previous;
extern symbolInfo *functionName;

extern YYSTYPE yylval;
extern symbolTable *table;
extern void insertParameters();
extern void insertFunctionName();

symbolInfo *findInSymbolTable(string name, string type)
{
	symbolInfo *si = table->lookUp(name);
	if(si == nullptr) return new symbolInfo(name, type);
	return new symbolInfo(si->name, si->type, si->typeSpecifier, si->size, si->offset);
	
}
string getEscape(string s)
{
	switch(s[1]){
			case 't':
				return "\t";
				
			case 'n':
				return "\n";
				
			case '\\':
				return "\\";
				
			case '\'':
				return "\'";
			case '\"':
				return "\"";
				
			case 'a':
				return "\a";
				
			case 'f':
				return "\f";
				
			case 'r':
				return "\r";
				
			case 'b':
				return "\b";
				
			case 'v':
				return "\v";
				
			case '0':
				return "\n";
			default:
				return "x";
				
		}
}


%}

WHITESPACE [ \t\v\r\f]
NEWLINE \n|\r\n
DIGIT [0-9]
LETTER [A-Za-z]
INTEGER {DIGIT}+
DECIMAL (({DIGIT}+\.{DIGIT}*)|({DIGIT}*\.{DIGIT}+))
FLOAT ({DECIMAL}|{INTEGER})([Ee][+-]?{INTEGER})?
TYPE_SPECIFIER int|float|void|char|double
KEYWORD if|for|else|while|return|println    
RELOP <|<=|>|>=|==|!=
MULOP [*/\%]
ADDOP [-+]
LOGICOP &&|\|\|
ID (_|{LETTER})(_|{LETTER}|{DIGIT})*
ESCAPE \\t|\\n|\\\\|\\\'|\\\"|\\a|\\f|\\r|\\b|\\v|\\0


%%


{WHITESPACE} {}
{NEWLINE} {
	line_count++;
	
}
{TYPE_SPECIFIER} {

	yylval.si =  new symbolInfo(yytext, "TYPE_SPECIFIER", yytext);
	previous = yylval.si;
	string sp = yytext;
	if(sp == "int") return INT;
	else if(sp == "float") return FLOAT;
	else if(sp == "void") return VOID;
	else if(sp == "char") return CHAR;
	else if(sp == "double") return DOUBLE;
	
}
{KEYWORD} {
	
	yylval.si = new symbolInfo(yytext,"KEYWORD");
	string sp = yytext;
	previous = yylval.si;
	
	if(sp == "if") return IF;
	else if(sp == "for") return FOR;
	else if(sp == "else") return ELSE;
	else if(sp == "while") return WHILE;
	else if(sp == "return") return RETURN;
	else if(sp == "println") return PRINTLN;

}

{ID} { 
	yylval.si = findInSymbolTable(yytext, "ID");
	if(previous->type == "TYPE_SPECIFIER")
		yylval.si->typeSpecifier = previous->name;
	previous = yylval.si;
	return ID;
}
{INTEGER} {
	
	yylval.si =  new symbolInfo(yytext, "CONST_INT", "int");
	previous = yylval.si;
	return CONST_INT;
}
{FLOAT} {
	
	yylval.si =  new symbolInfo(yytext, "CONST_FLOAT", "float");
	previous = yylval.si;
	return CONST_FLOAT;
}
{DECIMAL}(\.{INTEGER}?)+ {
	string txt = yytext;
	yyerror("Too many decimal points " + txt);
	yylval.si =  new symbolInfo(yytext, "CONST_INT", "int");
	previous = yylval.si;
	return CONST_INT;
}
{FLOAT}(\.{FLOAT}?)+ {
	string txt = yytext;
	yyerror("Ill formed number " + txt);
	yylval.si =  new symbolInfo(yytext, "CONST_INT", "int");
	previous = yylval.si;
	return CONST_INT;
}
{FLOAT}({LETTER}|_)({LETTER}|_|{FLOAT})* {
	string txt = yytext;
	yyerror("Invalid prefix on ID or invalid suffix on Number " + txt);
	yylval.si = findInSymbolTable(yytext, "ID");
	/*if(previous->type == "TYPE_SPECIFIER")
		yylval.si->typeSpecifier = previous->name;*/
	previous = yylval.si;
	return ID;
}

{RELOP} {
	yylval.si = new symbolInfo(yytext, "RELOP");
	previous = yylval.si;
	return RELOP;
}
{MULOP} {
	yylval.si = new symbolInfo(yytext, "MULOP");
	previous = yylval.si;
	return MULOP;
}
{ADDOP} {
	yylval.si = new symbolInfo(yytext, "ADDOP");
	previous = yylval.si;
	return ADDOP;
}
{LOGICOP} {
	yylval.si = new symbolInfo(yytext, "LOGICOP");
	previous = yylval.si;
	return LOGICOP;
}
";" { 
	yylval.si = new symbolInfo(yytext, "SEMICOLON");
	previous = yylval.si;
	functionName = nullptr;
	return SEMICOLON; 
}
"," { 
	yylval.si = new symbolInfo(yytext, "COMMA");
	previous = yylval.si;
	return COMMA; 
}
"[" { 
	yylval.si = new symbolInfo(yytext, "LTHIRD");
	previous = yylval.si;
	return LTHIRD; 
}
"]" { 
	yylval.si = new symbolInfo(yytext, "RTHIRD");
	previous = yylval.si;
	return RTHIRD; 
}
"(" { 
	start_line = line_count;
	yylval.si = new symbolInfo(yytext, "LPAREN");
	if(previous->type == "ID")
	{
		functionName = previous;
	}
	previous = yylval.si;
	return LPAREN; 
}
")" { 
	yylval.si = new symbolInfo(yytext, "RPAREN");
	previous = yylval.si;
	return RPAREN; 
}
"{" {
	yylval.si = new symbolInfo(yytext, "LCURL");
	previous = yylval.si;
	if(functionName != nullptr){
		insertFunctionName();
		offset = 0;	
	}
	table->enterNewScope();
	insertParameters();
	
	return LCURL; 
}
"}" {
	yylval.si = new symbolInfo(yytext, "RCURL");
	previous = yylval.si;
	
	return RCURL; 
}
"=" { 
	yylval.si = new symbolInfo(yytext, "ASSIGNOP");
	previous = yylval.si;
	return ASSIGNOP;
}
"!" { 
	yylval.si = new symbolInfo(yytext, "NOT");
	previous = yylval.si;
	return NOT;
}
"++" { 
	yylval.si = new symbolInfo(yytext, "INCOP");
	previous = yylval.si;
	return INCOP; 
}
"--" {
	yylval.si = new symbolInfo(yytext, "DECOP");
	previous = yylval.si;
	return DECOP; 
}


' {
	BEGIN CHARSTATE;
	str = "";
	lexeme = "'";
	
}
<CHARSTATE>{ESCAPE} {
	lexeme += yytext;
	str += getEscape(yytext);
}
<CHARSTATE>' {
	lexeme += "'";
	if(str.length() > 1) {
		yyerror("Multi character constant error " + lexeme);
	}
	else if(str.length() == 0)
	{
		yyerror("Empty character constant error " + lexeme);
	}
	else {
		yylval.si =  new symbolInfo(yytext, "CONST_CHAR", "char");
		previous = yylval.si;
		return CONST_CHAR;
	}
	
	BEGIN INITIAL;
}
<CHARSTATE>{NEWLINE} {
	yyerror("Unterminated character " + lexeme);
	line_count++;
	BEGIN INITIAL;
}

<CHARSTATE>. {
	lexeme += yytext;
	str += yytext;
}
"//" {
	BEGIN SINGLECOMMENTSTATE;
	lexeme = yytext;
	string_comment_start_line = line_count;
}
<SINGLECOMMENTSTATE>\\{NEWLINE} {
	lexeme += yytext;
	line_count++;
}
<SINGLECOMMENTSTATE>{NEWLINE} {
	line_count++;
	BEGIN INITIAL;
}
<SINGLECOMMENTSTATE>. {
	lexeme += yytext;
}
"/*" {
	BEGIN MULTICOMMENTSTATE;
	lexeme = yytext;
	string_comment_start_line = line_count;
}
<MULTICOMMENTSTATE>"*/" {
	lexeme += yytext;
	BEGIN INITIAL;
}
<MULTICOMMENTSTATE>. {
	lexeme += yytext;
}
<MULTICOMMENTSTATE>{NEWLINE} {
	lexeme += yytext;
	line_count++;
}
<MULTICOMMENTSTATE><<EOF>> {
	yyerror("Unterminated Comment " +lexeme, false, true);
	BEGIN INITIAL;
}


. {

	string msg =yytext;
	msg = "Unrecognized character " + msg;
	yyerror(msg);
	
}
