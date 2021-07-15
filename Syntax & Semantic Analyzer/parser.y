%{

#include<iostream>
#include<string>
#include<vector>
#include<fstream>
#include "symbolTable.h"



using namespace std;
extern FILE *yyin;
extern int error_count;
extern int line_count;
extern int start_line;
extern int string_comment_start_line;



symbolTable *table;
ofstream errorFile;


nonTerminal *parameters;
symbolInfo *functionName;
string currentFunction = "";


void logRule(string left, string right)
{
	cout << "Line " << line_count << ": " << left << " : " << right << endl << endl; 
}
void logPattern(symbolInfo *s)
{

	s->ToString();
	cout << endl << endl;
	
}
void logPattern(nonTerminal *nt)
{
	nt->ToString();
	cout << endl << endl;
}
void yyerror(string msg, bool functionError=false, bool multiline=false)
{
	error_count++;
	int line = functionError ? start_line : (multiline? string_comment_start_line : line_count);
	errorFile << "Error at line " << line << ": " << msg << endl << endl;
	cout << "Error at line " << line << ": " << msg << endl << endl;
}


void clearParameterList()
{
	parameters = nullptr;
}

void insertParameters()
{
	if(parameters == nullptr) return ;
	nonTerminal *nt = parameters->child;
	
	while(nt != nullptr)
	{
		if(nt->type == "ID"){
			
			if(!table->insertIntoCurrentScope(*nt))
			{
				yyerror("Multiple declaration of " + nt->name + " in parameter", true);
			}
		
		}
		nt = nt->sibling;
	}

	clearParameterList();

}

void addParamsToFunction(symbolInfo *func){

	if(parameters == nullptr) return ;

	nonTerminal *nt = parameters->child;
	
	while(nt != nullptr)
	{
		if(nt->type == "type_specifier") {
			func->addParameter(nt->typeSpecifier);
		}
		nt = nt->sibling;
	}
}

void insertFunctionName()
{
	
	
	addParamsToFunction(functionName);
	
	functionName->functionDefined();
	
	symbolInfo *declared = table->lookUp(functionName->name);
	
			
	if(declared == nullptr) {
		
		table->insertIntoCurrentScope(*(functionName));
	}
	
	else if(declared->funcProp == nullptr || declared->funcProp->defined)
	{
		
		yyerror("Multiple declaration of " + functionName->name, true);
	}
	
	else
	{
		
		string error = "";
		if(declared->typeSpecifier != functionName->typeSpecifier)
		{
			error = "Return type mismatch with function declaration in function " + declared->name;
		}
		else if(declared->funcProp->defined)
		{
		    error = "Multiple definition of function " + declared->name;
		}
		else if(declared->funcProp->getCount() != functionName->funcProp->getCount())
        	{
        		error = "Total number of arguments mismatch with declaration in function " + declared->name;
        	}
        	else 
        	{
        		error = declared->funcProp->getMismatch(functionName->funcProp);
        		if(error != "") error += declared->name;
        	}
		
		if(error.length()) yyerror(error, true);
		else declared->functionDefined();
	}
	
	currentFunction = functionName->name;
	functionName = nullptr;
	
	
	
}
bool arrayCheck(nonTerminal *nt)
{
	if(nt->size && (nt->child->sibling==nullptr || nt->child->sibling->type != "LTHIRD"))
	{
		yyerror("Type mismatch, " + nt->name + " is an array") ;
		return true;
		
	}
	else if(!nt->size && nt->child->sibling!=nullptr && nt->child->sibling->type == "LTHIRD")
	{
		yyerror(nt->name + " not an array") ;
		return true;
	}
	return false;
}
void checkParameterNames(nonTerminal *parameters, string functionName)
{
	
	if(parameters == nullptr) return ;
	bool nameFound = true;
	int i = 0;
	
	nonTerminal *now = parameters->child;
	
	while(now != nullptr)
	{
		if(now->type == "ID") nameFound = true;
		else if(now->type == "TYPE_SPECIFIER")
		{	
			i++;
			if(!nameFound)
			{
				yyerror(to_string(i) + "th parameter's name not given in function definition of " + functionName, true);
			}
			nameFound = false;
			
		}
		now = now->sibling;
	}
	
	if(!nameFound)
	{
		yyerror(to_string(i) + "th parameter's name not given in function definition of " + functionName, true);
	}
	

}

int yyparse(void);
int yylex(void);

%}

%union {
	symbolInfo* si; 
	nonTerminal* nt;
	
}
%token <si>	CONST_INT CONST_FLOAT CONST_CHAR ID INT FLOAT VOID CHAR DOUBLE FOR IF ELSE WHILE RETURN PRINTLN LOGICOP 
	RELOP MULOP ADDOP COMMA SEMICOLON LTHIRD RTHIRD LPAREN RPAREN LCURL RCURL ASSIGNOP NOT INCOP DECOP 
	

%type <nt> 	type_specifier  arguments argument_list expression_statement statement statements declaration_list var_declaration 
		compound_statement parameter_list func_definition func_declaration unit factor unary_expression term 
		simple_expression rel_expression logic_expression expression variable program start

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
start:			program		
			{ 
				$$ = new nonTerminal("", "program");
				$$->addNextChild($1);
				
				logRule("start", "program");
				
				
			}
;
program: 		program unit	
			{ 
			
				$$ = $1;
				$$->addNextChild($2);
				
				
				logRule("program", "program unit");
				logPattern($$);
				
				
			}
|	 		unit		
			{ 
				$$ = new nonTerminal("", "program");
				$$->addNextChild($1);
				
				logRule("program", "unit");
				logPattern($$);
				
				
				
				
			}
;	
unit: 			var_declaration		
			{ 
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				
				logRule("unit", "var_declaration");
				logPattern($$);
				
				
				
				
			}
|			func_declaration
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				logRule("unit", "func_declaration");
				logPattern($$);
				
				
				
				
				
			}
|			func_definition
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				logRule("unit", "func_definition");
				logPattern($$);
				
				
				
			}
|			error unit
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($2);
				
				yyclearin;
				yyerrok;
				
				
				
			}
;

func_declaration: 	type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
			{
			
				$2->typeSpecifier = $1->typeSpecifier;
				$2->setFuncProp();
				
				
				addParamsToFunction($2);
				clearParameterList();
				
				if(!table->insertIntoCurrentScope(*($2)))
				{
					yyerror("Multiple declaration of " + $2->name);
				}
				
				$$ = new nonTerminal();
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				
				
				logRule("func_declaration","type_specifier ID LPAREN parameter_list RPAREN SEMICOLON");
				logPattern($$);
				
			}
|			type_specifier ID LPAREN RPAREN SEMICOLON 
			{
			
				$2->typeSpecifier = $1->typeSpecifier;
				$2->setFuncProp();
				
				if(!table->insertIntoCurrentScope(*($2)))
				{
					yyerror("Multiple declaration of " + $2->name);
				}
				clearParameterList();
				
				$$ = new nonTerminal();
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				
			
				
				logRule("func_declaration","type_specifier ID LPAREN RPAREN SEMICOLON");
				logPattern($$);
				
			}
		
;
func_definition:	type_specifier ID LPAREN parameter_list RPAREN compound_statement
			{
				
				
				$$ = new nonTerminal();
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				
				
				logRule("func_definition","type_specifier ID LPAREN parameter_list RPAREN compound_statement");
				logPattern($$);
				checkParameterNames($4, $2->name);
				
				
			}
|			type_specifier ID LPAREN RPAREN compound_statement
			{
			
				$$ = new nonTerminal();
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				
				
				logRule("func_definition","type_specifier ID LPAREN RPAREN compound_statement");
				logPattern($$);
				
				
				
			}
		
;				
parameter_list: 	parameter_list COMMA type_specifier ID
			{	
			
				$4->typeSpecifier = $3->typeSpecifier;
			
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				
				logRule("parameter_list","parameter_list COMMA type_specifier ID");
				logPattern($$);
				
				if($3->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
				
			}
|			parameter_list COMMA type_specifier
			{
				
				$$ = $1;
				$1->addNextChild($2);
				$1->addNextChild($3);
				
				
				logRule("parameter_list","parameter_list COMMA type_specifier");
				logPattern($$);
				
				if($3->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
				
			}
|			type_specifier ID
			{
				
				$2->typeSpecifier = $1->typeSpecifier;
				
				$$ = new nonTerminal("", "parameter_list");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				
				logRule("parameter_list","type_specifier ID");
				logPattern($$);
				
				if($1->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
			}
|			type_specifier
			{
				$$ = new nonTerminal("", "parameter_list");
				$$->addNextChild($1);
				
				
				logRule("parameter_list","type_specifier");
				logPattern($$);
				
				if($1->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
				
			}
			
|			type_specifier ID error
			{
				$2->typeSpecifier = $1->typeSpecifier;
				
				$$ = new nonTerminal("", "parameter_list");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				
				logRule("parameter_list", "type_specifier ID error");
				
				yyclearin;
				yyerrok;
				
				logPattern($$);
				
				if($1->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
			}
|			parameter_list COMMA type_specifier ID error
			{
			
				$4->typeSpecifier = $3->typeSpecifier;
				
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				logRule("parameter_list", "parameter_list COMMA type_specifier ID error");
				yyclearin;
				yyerrok;
				
				
				logRule("parameter_list","parameter_list COMMA type_specifier ID");
				logPattern($$);
				
				if($3->typeSpecifier == "void")
				{
					yyerror("Parameter type cannot be void");
				}
				
				parameters = $$;
				
			}

;
var_declaration: 	type_specifier declaration_list SEMICOLON	
			{
				$$ = new nonTerminal("", "var_declaration");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				logRule("var_declaration", "type_specifier declaration_list SEMICOLON");
				logPattern($$);
				
				
				if($1->typeSpecifier == "void")
				{
					yyerror("Variable type cannot be void");
				}
				else {
					nonTerminal *nt = $2->child;
					while(nt != nullptr)
					{
						if(nt->type == "ID") {
							
							nt->typeSpecifier = $1->typeSpecifier; 
							
							
							if(!table->insertIntoCurrentScope(*nt))
							{
								yyerror("Multiple declaration of "+nt->name);
							}
							
						}
						nt = nt->sibling;
					}
				}
			}
			
|			type_specifier declaration_list error SEMICOLON
			{
				$$ = new nonTerminal("", "var_declaration");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($4);
				
				
				yyclearin;
				yyerrok;
				logPattern($$);
				
				 
				
				if($1->typeSpecifier == "void")
				{
					yyerror("Variable type cannot be void");
				}
				else {
					nonTerminal *nt = $2;
					while(nt != nullptr)
					{
						if(nt->type == "ID") {
						
							nt->typeSpecifier = $1->typeSpecifier; 
							if(!table->insertIntoCurrentScope(*nt))
							{
								yyerror("Multiple declaration of "+nt->name);
							}
							
							
						}
						nt = nt->sibling;
					}
				}
			}
;
type_specifier: 	INT	
			{
				
				logRule("type_specifier","INT"); 
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
|			FLOAT 	
			{ 
				logRule("type_specifier","FLOAT"); 
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
|			VOID 	
			{ 
				logRule("type_specifier","VOID"); 
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
|			CHAR 	
			{ 
				logRule("type_specifier","CHAR"); 
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
|			DOUBLE 	
			{
				logRule("type_specifier","DOUBLE"); 
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
			
|			type_specifier error
			{
				logRule("type_specifier", "type_specifier error");
				yyclearin;
				yyerrok;
				$$ = new nonTerminal("", "type_specifier");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier;
				logPattern($$);
			}
			
			
;
declaration_list:	declaration_list COMMA ID 
			{
			
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				logRule("declaration_list","declaration_list COMMA ID"); 
				logPattern($$);
				
				
			} 
|			declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
			{
				
				$3->setSize(stoi($5->name));
				
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				
				
				logRule("declaration_list","declaration_list COMMA ID LTHIRD CONST_INT RTHIRD"); 
				logPattern($$);
				
				
			}			
|			ID	
			{ 
				$$ = new nonTerminal("", "declaration_list");
				$$->addNextChild($1);
				
				logRule("declaration_list","ID");
				logPattern($$);
				
				
			}
|			ID LTHIRD CONST_INT RTHIRD
			{
			
				$1->setSize(stoi($3->name));
				
				$$ = new nonTerminal("", "declaration_list");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				
				logRule("declaration_list", "ID LTHIRD CONST_INT RTHIRD");
				logPattern($$);
				
				
			}
			
|			declaration_list COMMA error ID
			{
				yyclearin;
				yyerrok;
				
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($4);
				
				logPattern($$);
				
				
			}
|			declaration_list error COMMA ID 
			{
				yyclearin;
				yyerrok;
				
				$$ = $1;
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				logPattern($$);
				
				
			}
|			declaration_list COMMA error ID LTHIRD CONST_INT RTHIRD
			{
				yyclearin;
				yyerrok;
				$4->setSize(stoi($6->name));
				
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				$$->addNextChild($7);
			
				
				logPattern($$);
				
				
				
			}
|			declaration_list error COMMA ID LTHIRD CONST_INT RTHIRD
			{
				yyclearin;
				yyerrok;
				$4->setSize(stoi($6->name));
				
				$$ = $1;
				
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				$$->addNextChild($7);
				
				logPattern($$);
				
				
			}
			
;
compound_statement:	LCURL statements RCURL
			{
				logRule("compound_statement", "LCURL statements RCURL");
				$$ = new nonTerminal("", "compound_statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				logPattern($$);
				table->print("A");
				table->exitScope();
				
				
			
			}
|			LCURL RCURL
			{
				logRule("compound_statement", "LCURL RCURL");
				$$ = new nonTerminal("", "compound_statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				logPattern($$);
				table->print("A");
				table->exitScope();
				
				
			}
			
|			LCURL statements error RCURL			
			{
				yyclearin;
				yyerrok;
				
				$$ = new nonTerminal("", "compound_statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($4);
				
				
				
				logPattern($$);
				table->print("A");
				table->exitScope();
				
				
				
				
			}
			
;
statements:		statement
			{
				logRule("statements", "statement");
				$$ = new nonTerminal("", "statements");
				$$->addNextChild($1);
				
				logPattern($$);
				
				
				
			}
|			statements statement
			{
				logRule("statements", "statements statement");
				$$ = $1;
				$$->addNextChild($2);
				
				logPattern($$);
				
				
			}
;
statement: 		var_declaration
			{
				logRule("statement", "var_declaration");
				
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
				
				
			}
| 			expression_statement
			{
				logRule("statement", "expression_statement");
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
								
			}
| 			compound_statement
			{
				logRule("statement", "compound_statement");
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
				
				
			}
| 			FOR LPAREN expression_statement expression_statement expression RPAREN statement
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				$$->addNextChild($7);
				
				
				logRule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement");
				logPattern($$);
				
				
				
				
			}
| 			IF LPAREN expression RPAREN statement	%prec LOWER_THAN_ELSE
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				
				
				logRule("statement", "IF LPAREN expression RPAREN statement");
				logPattern($$);
				
				
			}
| 			IF LPAREN expression RPAREN statement ELSE statement
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				$$->addNextChild($6);
				$$->addNextChild($7);
				
				
				logRule("statement", "IF LPAREN expression RPAREN statement ELSE statement");
				logPattern($$);
				
				
			}
| 			WHILE LPAREN expression RPAREN statement
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				
				
				
				logRule("statement", "WHILE LPAREN expression RPAREN statement");
				logPattern($$);
				
				
			}
| 			PRINTLN LPAREN ID RPAREN SEMICOLON
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				$$->addNextChild($5);
				
				
				logRule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON");
				logPattern($$);
				
				
				
			}
| 			RETURN expression SEMICOLON
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				logRule("statement", "RETURN expression SEMICOLON");
				logPattern($$);
				
				
			}
|			func_definition
			{
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				
				logPattern($$);
				yyerror("A function is defined inside a function", true);	
			}
|			func_declaration
			{
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				
				logPattern($$);
				yyerror("A function is declared inside a function", true);
			
			}
			
|			error statement
			{
				yyclearin;
				yyerrok;
				
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($2);
				
				logPattern($$);
				
			}
			
			
;	  
expression_statement: 	SEMICOLON
			{
				$$ = new nonTerminal("", "expression_statement");
				$$->addNextChild($1);
				
				logRule("expression_statement", "SEMICOLON");
				logPattern($$);
				
			}			
|			expression SEMICOLON
			{
				logRule("expression_statement", "expression SEMICOLON");
				$$ = new nonTerminal("", "expression_statement");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				logPattern($$);
				
				$$->name = $1->name;
				
			}
;	  
variable: 		ID
			{
				$$ = new nonTerminal("", "variable");
				$$->addNextChild($1);
				$$->typeSpecifier = $1->typeSpecifier ;
				
				logRule("variable", "ID");
				logPattern($$);
				
				if(table->lookUp($1->name) == nullptr)
				{
					yyerror("Undeclared variable " + $1->name );
				}
				
				
				$$->name = $1->name;
				$$->size = $1->size;
				
				
			}		
| 			ID LTHIRD expression RTHIRD
			{
				
				$$ = new nonTerminal("", "variable");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				
				$$->typeSpecifier = $1->typeSpecifier ;
				
				logRule("variable", "ID LTHIRD expression RTHIRD");
				logPattern($$);
				
				if(table->lookUp($1->name) == nullptr)
				{
					yyerror("Undeclared variable " + $1->name );
				}
				
				if($3->typeSpecifier != "int")
				{
					yyerror("Expression inside third brackets not an integer");
				}
				
				
				$$->name = $1->name;
				$$->size = $1->size;
				
				
			}
;	 
expression: 		logic_expression
			{
				logRule("expression", "logic_expression");
				$$ = new nonTerminal("", "expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
			}	
| 			variable ASSIGNOP logic_expression
			{
				$$ = new nonTerminal("", "expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				logRule("expression", "variable ASSIGNOP logic_expression");
				logPattern($$);
				
				if($3->typeSpecifier == "void" || $1->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				else if(!arrayCheck($1) && $1->typeSpecifier.length() && $3->typeSpecifier.length() && 
					$1->typeSpecifier != $3->typeSpecifier)
				{
					if($1->typeSpecifier == "float" && $3->typeSpecifier == "int") ;
					else yyerror("Type Mismatch ");
				}
				$$->typeSpecifier = "int";
				
				
				
				
				
			}	
;			
logic_expression: 	rel_expression
			{
				logRule("logic_expression", "rel_expression");
				$$ = new nonTerminal("", "logic_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
			}
| 			rel_expression LOGICOP rel_expression
			{
				$$ = new nonTerminal("", "logic_expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				
				$$->typeSpecifier = "int";
				logRule("logic_expression", "rel_expression LOGICOP rel_expression");
				logPattern($$);
				
				if($1->typeSpecifier == "void" || $3->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				
				
			}
		
;			
rel_expression: 	simple_expression 
			{
				logRule("rel_expression", "simple_expression");
				$$ = new nonTerminal("", "rel_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
				
			}
| 			simple_expression RELOP simple_expression
			{
				
				$$ = new nonTerminal("", "rel_expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				$$->typeSpecifier = "int";
				
				logRule("rel_expression", "simple_expression RELOP simple_expression");
				logPattern($$);
				if($1->typeSpecifier == "void" || $3->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				
				
			}	
;				
simple_expression: 	term 
			{
				logRule("simple_expression", "term");
				$$ = new nonTerminal("", "simple_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
			}
| 			simple_expression ADDOP term 
			{
				
				$$ = new nonTerminal("", "simple_expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				
				if($1->typeSpecifier == "float" || $3->typeSpecifier == "float")
					$$->typeSpecifier = "float";
				else 
					$$->typeSpecifier = "int";
					
				logRule("simple_expression", "simple_expression ADDOP term");
				logPattern($$);
				
				if($1->typeSpecifier == "void" || $3->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				
				
			}
;					
term:			unary_expression
			{
				
				logRule("term", "unary_expression");
				$$ = new nonTerminal("", "term");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
			}
|			term MULOP unary_expression
			{
				
				$$ = new nonTerminal("", "term");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				logRule("term", "term MULOP unary_expression");
				logPattern($$);
				
				if($1->typeSpecifier == "void" || $3->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				else if($2->name == "%")
				{
					if(($1->typeSpecifier != "int") || ($3->typeSpecifier != "int"))
					{
						yyerror("Non-Integer operand on modulus operator");
					}
					else
					{
						
						if($3->typeSpecifier == "int" && $3->getName()=="0")
						{
							yyerror("Modulus by Zero");

						}
					}
					$$->typeSpecifier = "int";
				}
				else if($1->typeSpecifier == "float" || $3->typeSpecifier == "float")
					$$->typeSpecifier = "float";
				else 
					$$->typeSpecifier = "int";	
					
				
			}
;

unary_expression: 	ADDOP unary_expression 
			{
				$$ = new nonTerminal("", "unary_expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				
				logRule("unary_expression", "ADDOP unary_expression");
				logPattern($$);
				
				if($2->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				
				$$->typeSpecifier = $2->typeSpecifier;
				
				
			} 
| 			NOT unary_expression 
			{
				$$ = new nonTerminal("", "unary_expression");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				$$->typeSpecifier = "int";
				
				logRule("unary_expression", "NOT unary_expression");
				logPattern($$);
				if($2->typeSpecifier == "void")
				{
					yyerror("Void function used in expression");
				}
				
				
				
			}
| 			factor 
			{
				logRule("unary_expression", "factor");
				$$ = new nonTerminal("", "unary_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				
			}
;	
factor: 		variable 
			{
				logRule("factor", "variable");
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				
				logPattern($$);
				arrayCheck($1);
				
				
				
			}
| 			ID LPAREN argument_list RPAREN
			{
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				$$->addNextChild($4);
				
				
				
				logRule("factor", "ID LPAREN argument_list RPAREN");
				logPattern($$);
				
				symbolInfo *declared = table->lookUp($1->name);
				
				
				int arg_cnt = 0;
				
				
				if(declared == nullptr) {
					yyerror("Undeclared function " + $1->name);
				}
				else if(declared->funcProp == nullptr)
				{
					yyerror("Function call made with non-function type identifier "+$1->name);
				}
				else if(declared->funcProp->defined == 0)
				{
					yyerror("Undefined function " + $1->name);
				}
				else {
					
					nonTerminal *argument = $3->child;
					
					
					while(argument != nullptr)
					{
						if(argument->type == "logic_expression"){
							$1->addParameter(argument->typeSpecifier);
							arg_cnt++;
						}
						
						argument = argument->sibling;
					}
					if(arg_cnt != declared->funcProp->getCount())
					{
						yyerror("Total number of arguments mismatch in function " + $1->name); 
					}
					else {
						string error = declared->funcProp->getMismatch($1->funcProp);
						if(error.length()) yyerror(error +  $1->name);
					}
					
					$1->typeSpecifier = declared->typeSpecifier;
				}
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				
			}
| 			LPAREN expression RPAREN
			{
				
				logRule("factor", "LPAREN expression RPAREN");
				$$ = new nonTerminal("", "factor");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				logPattern($$);
				
				$$->typeSpecifier = $2->typeSpecifier;
				
				$$->name = $2->name;
				
			}
| 			CONST_INT 
			{
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				
				logRule("factor", "CONST_INT");
				logPattern($$);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				
			}
| 			CONST_FLOAT
			{
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				
				logRule("factor", "CONST_FLOAT");
				logPattern($$);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				
			}
|			CONST_CHAR
			{
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				
				logRule("factor", "CONST_CHAR");
				logPattern($$);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				
			}
| 			variable INCOP
			{	
				
				logRule("factor", "variable INCOP");
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				logPattern($$);
				arrayCheck($1);
				
								
			} 
| 			variable DECOP
			{
				logRule("factor", "variable DECOP");
				$$ = new nonTerminal("", "factor");
				$$->addNextChild($1);
				$$->addNextChild($2);
				
				
				$$->typeSpecifier = $1->typeSpecifier;
				
				
				logPattern($$);
				arrayCheck($1);
				
			
			}
;
argument_list: 		arguments
			{
				
				logRule("argument_list", "arguments");
				$$ = $1;
				logPattern($$);
			}
|			
			{
				
				$$ = new nonTerminal("", "argument_list");
				logRule("argument_list", "");
				
			}
;

arguments: 		arguments COMMA logic_expression
			{
				
				logRule("arguments", "arguments COMMA logic_expression");
				$$ = $1;
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				logPattern($$);
				
				
				
			}
|			logic_expression
			{
				logRule("arguments", "logic_expression");
				
				$$ = new nonTerminal("", "arguments");
				$$->addNextChild($1);
				logPattern($$);
				
			}
;


%%

int main(int argc,char *argv[])
{

	if(argc != 2)
	{
		cout << "Please provide a file name" << endl;
		return 0;
	}
	FILE *fin = fopen(argv[1],"r");
	if(fin == NULL)
	{
		cout << "Can't open file" << endl;
		return 0;
	}
	yyin = fin;
	freopen("log.txt", "w", stdout);
	errorFile.open("error.txt", ios::out);
	
	
	table = new symbolTable(30);
	yyparse();
	
	
	table->print("A");
	cout << "Total Lines: " << line_count << endl;
	cout << "Total Errors: " << error_count << endl << endl;
	
	
	errorFile.close();
	fclose(yyin);


}
