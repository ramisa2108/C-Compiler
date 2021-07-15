%option c++ noyywrap
%x STRINGSTATE
%x CHARSTATE
%x SINGLECOMMENTSTATE
%x MULTICOMMENTSTATE

%{

#include<iostream>
#include<fstream>
#include<string>
#include<sstream>
#include "symbolTable.h"
using namespace std;

ofstream token_file;

int line_count = 1;
int error_count = 0;
symbolTable *symTab = new symbolTable(7);
symbolInfo *token;
string str;
string lexeme;
int start_line;

string toUpper(char *original, int length){

	string upperCase = "";
	for(int i=0;i<length;i++){
		if(original[i] >= 'a' && original[i] <= 'z') upperCase += original[i] - 'a' + 'A';
		else upperCase += original[i];
	}
	return upperCase;
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


void insertLog(string tokenName, string lexeme, bool multiline=false){
	int line_no = multiline ? start_line : line_count;
	cout << "Line no " << line_no << ": Token <" <<  tokenName << "> Lexeme " << lexeme << " found" ;
	
	if(tokenName == "STRING" || tokenName == "CONST_CHAR") cout << " --> <" << tokenName << ", " << str << ">";
	cout << endl << endl;	
}
void insertError(string errorName, string lexeme, bool multiline=false){

	error_count++;
	int line_no = multiline ? start_line : line_count;
	cout << "Error at line no " << line_no << ": " << errorName << " " << lexeme << endl << endl;
}
void insertToken(string tokenName, string attribute="")
{
	token = new symbolInfo(tokenName, attribute);
	token_file << "<" << tokenName;
	if(attribute != "") token_file << ", " << attribute;
	token_file << "> ";
}

%}

DIGIT [0-9]
LETTER [A-Za-z]
WHITESPACE [ \t\v\f\r]+
NEWLINE \n|\r\n
KEYWORD if|for|do|int|float|void|switch|default|else|while|break|char|double|return|case|continue
RELOP <|<=|>|>=|==|!=
MULOP [*/\%]
ESCAPE \\t|\\n|\\\\|\\\'|\\\"|\\a|\\f|\\r|\\b|\\v|\\0
INTEGER {DIGIT}+
DECIMAL {INTEGER}(\.){INTEGER}?
FLOAT ({INTEGER}|{DECIMAL})([Ee][+-]?{INTEGER})?
%%
{WHITESPACE} {}
{NEWLINE} { line_count++; }
{KEYWORD} {  

	string keyword = toUpper(yytext, yyleng);
	insertToken(keyword);
	insertLog(keyword, yytext);
}
	
"+" |
"-" { 
	insertToken("ADDOP", yytext);
	insertLog("ADDOP", yytext);
}
{MULOP} {
	insertToken("MULOP", yytext);
	insertLog("MULOP", yytext);
	
}
"++" |
"--" {
	insertToken("INCOP", yytext);
	insertLog("INCOP", yytext);
}
{RELOP} {
	insertToken("RELOP", yytext);
	insertLog("RELOP", yytext);
}
"=" {
	insertToken("ASSIGNOP", yytext);
	insertLog("ASSIGNOP", yytext);
}
"&&" |
"\|\|" {
	insertToken("LOGICOP", yytext);
	insertLog("LOGICOP", yytext);
}
"!" {
	insertToken("NOT", yytext);
	insertLog("NOT", yytext);
}
"(" {
	insertToken("LPAREN", yytext);
	insertLog("LPAREN", yytext);
}
")" {
	insertToken("RPAREN", yytext);
	insertLog("RPAREN", yytext);
}
"{" {
	insertToken("LCURL", yytext);
	insertLog("LCURL", yytext);
	symTab->enterNewScope();
}
"}" {
	insertToken("RCURL", yytext);
	insertLog("RCURL", yytext);
	symTab->exitScope();
}
"[" {
	insertToken("LTHIRD", yytext);
	insertLog("LTHIRD", yytext);
}
"]" {
	insertToken("RTHIRD", yytext);
	insertLog("RTHIRD", yytext);
}
"," {
	insertToken("COMMA", yytext);
	insertLog("COMMA", yytext);
}
";" {
	insertToken("SEMICOLON", yytext);
	insertLog("SEMICOLON", yytext);
}
{INTEGER} {
	insertToken("CONST_INT", yytext);
	insertLog("CONST_INT", yytext);
	symTab->insertIntoCurrentScope( yytext, "CONST_INT");
	
}
{FLOAT} {
	insertToken("CONST_FLOAT", yytext);
	insertLog("CONST_FLOAT", yytext);
	symTab->insertIntoCurrentScope( yytext, "CONST_FLOAT");
	
}
{DECIMAL}(\.{INTEGER}?)+ {
	insertError("Too many decimal points", yytext);
}
{FLOAT}(\.{FLOAT}?)+ {
	insertError("Ill formed number", yytext);
}
{FLOAT}({LETTER}|_)+{FLOAT}? {
	insertError("Invalid prefix on ID or invalid suffix on Number", yytext);
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
		insertError("Multi character constant error", lexeme);
	}
	else if(str.length() == 0)
	{
		insertError("Empty character constant error", lexeme);
	}
	else {
		insertToken("CONST_CHAR", str);
		insertLog("CONST_CHAR", lexeme);
		symTab->insertIntoCurrentScope(lexeme, "CONST_CHAR");
	}
	
	BEGIN INITIAL;
}
<CHARSTATE>{NEWLINE} {
	insertError("Unterminated character", lexeme);
	line_count++;
	BEGIN INITIAL;
}

<CHARSTATE>. {
	lexeme += yytext;
	str += yytext;
}
({LETTER}|_)({LETTER}|_|{DIGIT})* {
	insertToken("ID", yytext);
	insertLog("ID", yytext);
	symTab->insertIntoCurrentScope(yytext, "ID");
}


\" {
	BEGIN STRINGSTATE;
	str = yytext;
	lexeme = yytext;
	start_line = line_count;
}
<STRINGSTATE>\" {
	lexeme += yytext;
	str += yytext;
	insertToken("STRING", str);
	insertLog("STRING", lexeme, true);
	BEGIN INITIAL;
}

<STRINGSTATE>\\\" {
	str += "\"";
	lexeme += yytext;
}
<STRINGSTATE>{ESCAPE} {
	str += getEscape(yytext);
	lexeme += yytext;
}
<STRINGSTATE>\\{NEWLINE} {
	line_count++;
	lexeme += yytext;
}
<STRINGSTATE>{NEWLINE} {
	
	insertError("Unterminated String", lexeme, true);
	
	line_count++;
	BEGIN INITIAL;
}
<STRINGSTATE><<EOF>> {
	insertError("Unterminated String", lexeme, true);
	BEGIN INITIAL;
}
<STRINGSTATE>. {
	str += yytext;
	lexeme += yytext;
}
"//" {
	BEGIN SINGLECOMMENTSTATE;
	lexeme = yytext;
	start_line = line_count;
}
<SINGLECOMMENTSTATE>\\{NEWLINE} {
	lexeme += yytext;
	line_count++;
}
<SINGLECOMMENTSTATE>{NEWLINE} {
	insertLog("COMMENT", lexeme, true);
	line_count++;
	BEGIN INITIAL;
}
<SINGLECOMMENTSTATE>. {
	lexeme += yytext;
}
"/*" {
	BEGIN MULTICOMMENTSTATE;
	lexeme = yytext;
	start_line = line_count;
}
<MULTICOMMENTSTATE>"*/" {
	lexeme += yytext;
	insertLog("COMMENT", lexeme, true);
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
	insertError("Unterminated Comment", lexeme, true);
	BEGIN INITIAL;
}

<<EOF>> { 
	symTab->print("A");
	cout << "Total lines: " << line_count << endl << "Total errors: " << error_count << endl; 
	return 0;
}
. {
	insertError("Unrecognized character", yytext);
}
%%

int main(int argc, char *argv[]){
	
	if(argc != 2)
	{
		cout << "Please provide input file name and try again" << endl;
		return 0;
	}
	
	ifstream fin(argv[1]);
	if(fin.fail())
	{
		cout << "Cannot open specified file" << endl;
		return 0;
	}
	
	token_file.open("token.txt", ios::out);
	freopen("log.txt", "w", stdout);

	yyFlexLexer *lexer = new yyFlexLexer(&fin);
	lexer->yylex();
	
	token_file.close();
	fin.close();
	
	
}
