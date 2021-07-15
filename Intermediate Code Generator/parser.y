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
extern int offset;

int label_count = 0;



symbolTable *table;
vector<string> allVariables;

ofstream errorFile;
ofstream asmFile;
ofstream optimizedasmFile;


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

string newLabel(){
	string label = "L" + to_string(label_count);
	label_count++;
	return label;
}
int nextOffset(){
	offset+=2;
	return offset;
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
			nt->setOffset(nextOffset());
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
	if(nt->size && !nt->arrayIndexAddress)
	{
		yyerror("Type mismatch, " + nt->name + " is an array") ;
		return true;
		
	}
	else if(!nt->size && nt->arrayIndexAddress)
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

string getWordPosition(symbolInfo *si)
{
	if(si->offset == 0)
	{
		return si->name;
	}
	else 
	{
		return "word ptr[bp - " + to_string(si->offset) + "]";
	}
}
string printFuncAsm(){

	string code = string("print PROC\n") + 
			"\tpush bp\n" + 
			"\tmov bp, sp\n" + 
			"\tsub sp, 2\n" +
			
			 
			"\tmov ax, word ptr[bp + 4]\n" + 
			 
    			"\tmov bx, 10D\n\n" + 
    			
    			"\txor cx, cx\n" + 
    			
    			"\txor dx, dx\n" +
    
    			"\t; check if the number is negative\n" +
    			"\tcmp ax, 0\n" +
    			"\tjnl extract_digits\n" +
    			"\tpush ax\n" + 
    			"\tmov ah, 2\n" +
    			"\tmov dl, '-'\n" +
    			"\tint 21H\n" +
    			"\tpop ax\n" + 
    			"\tneg ax\n\n" +
    
    			"\textract_digits:\n" +
    				"\t\t; clear dx\n" + 
        			"\t\txor dx, dx\n\n" +
        			"\t\tidiv bx ; performs ax = ax / bx, dx = ax % bx\n" +
        			"\t\tpush dx\n" +
        			"\t\tinc cx\n" +
        			"\t\tcmp ax, 0\n" +
        			"\t\tjne extract_digits\n\n" +
    
    			"\tmov ah, 2\n" +
    			"\tprint_digits:\n" + 
        			"\t\tpop dx\n" +
        			"\t\tadd dl, 30H\n" +
				"\t\tint 21H\n" +
				"\t\tloop print_digits\n\n" +  
				
					   
        		
			    "\tmov dl, 0AH\n" +
			    "\tint 21H\n" +
			    "\tmov dl, 0DH\n" +
			    "\tint 21H\n" +
			    
			    "\tadd sp, 2\n" +
			    "\tpop bp\n" + 
			    "\tret\n\n" +
        
		"print ENDP\n\n";
		
	return code;
	
}
string initCode(){
	return "\tmov ax, @data\n\tmov ds, ax\n\n";

}
string exitCode(){
	return "\tmov ah, 4CH\n\tint 21H\n\n";
}
void printCode(string mainCode){

	
	asmFile << ".MODEL small" << endl << ".STACK 100h" << endl << ".DATA" << endl;
	for(string var: allVariables){
		asmFile <<  "\t" << var << endl; 
	}
	asmFile << ".CODE" << endl;
	asmFile << printFuncAsm() << endl;
	asmFile << mainCode << endl;
	asmFile << "END main" << endl;
	
	asmFile.close();

}
bool isComment(string line)
{
	int found = line.find(";");
	return found != string::npos;
}


bool repMov(string now, string prev)
{
	int m1 = now.find("mov");
	int m2 = prev.find("mov");
	
	if(m1 == string::npos || m2 == string::npos) return false;
	
	int c1 = now.find(",");
	int c2 = prev.find(",");
	
	if((now.substr(m1 + 4, c1 - m1 - 4) == prev.substr(c2+2, prev.length() - c2 - 2)) && 
		(prev.substr(m2 + 4, c2 - m2 - 4) == now.substr(c1 + 2, now.length() - c1 - 2)))
		return true;
	else return false;
	
	
}

void printOptimizedCode(string maincode){
	
	
	ifstream asmFile;
	
	asmFile.open("code.asm", ios::in);
	
	string now, prev = "";
	vector<string>code;
	while(getline(asmFile, now)){
		
		
		if(!isComment(now)){
			if(repMov(now, prev))
			{
				code.push_back("");
			}
			else 
			{
				code.push_back(now);
				prev = now;
			}
			
			
		}
		else {
		
			code.push_back(now);
		}
	}
	
	for(string c:code)
	{
		optimizedasmFile << c  << endl;	
	}
	
	asmFile.close();
	optimizedasmFile.close();
	

	
	
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
				
				/* code section */
				if(error_count == 0){
					printCode($1->code);
					printOptimizedCode($1->code);
				}
				else
				{
					asmFile.close();
					optimizedasmFile.close();
				}
			}
;
program: 		program unit	
			{ 
			
				$$ = $1;
				$$->addNextChild($2);
				
				
				logRule("program", "program unit");
				logPattern($$);
				
				/* code section */
				$$->code = $1->code + $2->code;
			}
|	 		unit		
			{ 
				$$ = new nonTerminal("", "program");
				$$->addNextChild($1);
				
				logRule("program", "unit");
				logPattern($$);
				
				/* code section */
				$$->code = $1->code;
				
				
			}
;	
unit: 			var_declaration		
			{ 
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				
				logRule("unit", "var_declaration");
				logPattern($$);
				
				/* code section */
				$$->code = $1->code;
				
				
			}
|			func_declaration
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				logRule("unit", "func_declaration");
				logPattern($$);
				
				/* code section */
				$$->code = $1->code;
				
				
				
			}
|			func_definition
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($1);
				
				logRule("unit", "func_definition");
				logPattern($$);
				
				/* code section */
				$$->code = $1->code;
				
			}
|			error unit
			{
				$$ = new nonTerminal("", "unit");
				$$->addNextChild($2);
				
				yyclearin;
				yyerrok;
				
				/* code section */
				$$->code = $2->code;
				
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
				
				/* code section */
				$$->code = $2->name + " PROC\n";
				if($2->name == "main")
				{
					$$->code += initCode();
				}
				
				// init part
				$$->code += "\tpush bp\n";
				$$->code += "\tmov bp, sp\n";
				$$->code += "\tsub sp, " + to_string(offset + 2) + "\n\n";
				
				if($2->name != "main")
				{
					int param_count = 0;
					nonTerminal *nt = $4->child;
					while(nt != nullptr){
					
						if(nt->type == "type_specifier") param_count++;
						nt = nt->sibling;
					}
					
					for(int i=1, j=param_count+1;i<=param_count;i++,j--)
					{	
						$$->code += "\tmov ax, word ptr[bp + " + to_string(j*2) + "]\n";
						$$->code += "\tmov word ptr[bp - " + to_string(i*2) + "], ax\n";
					}	
				}

				$$->code += $6->code;
				
				
				// exit part
				
				$$->code += "\tret_" + $2->name + ":\n";
				$$->code += "\tadd sp, " + to_string(offset + 2) + "\n";
				$$->code += "\tpop bp\n\n";
				
				if($2->name == "main")
				{
					
					$$->code +=  exitCode();
				}
				else 
				{
					$$->code += "\tret\n";
				}
				$$->code += $2->name + " ENDP\n";
				
				
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
				
				/* code section */
				$$->code = $2->name + " PROC\n";
				if($2->name == "main")
				{
					$$->code += initCode();
				}
				
				// init part
				$$->code += "\tpush bp\n";
				$$->code += "\tmov bp, sp\n";
				$$->code += "\tsub sp, " + to_string(offset + 2) + "\n\n";
				
				$$->code += $5->code;
				
				// exit part
				$$->code += "\tret_" + $2->name + ":\n";
				
				$$->code += "\tadd sp, " + to_string(offset + 2) + "\n";
				$$->code += "\tpop bp\n\n";
				
				if($2->name == "main")
				{
					$$->code += exitCode();
				}
				else 
				{
					$$->code += "\tret\n";
				}
				$$->code += $2->name + " ENDP\n";
				
				
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
				
				bool isGlobal = table->checkIfGlobal();
				
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
							if(isGlobal) {
								
								nt->setOffset(0);
								if(nt->size)
								{
								allVariables.push_back(nt->name + " dw " + to_string(nt->size) + " dup(?)");
								}
								else{
									allVariables.push_back(nt->name + " dw ? ");	
								}
							}
							else {
								if(nt->size)
								{
									offset += nt->size * 2;
									nt->setOffset(offset);
								}
								else {
									nt->setOffset(nextOffset());
									
								}
							}
							
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
				
				bool isGlobal = table->checkIfGlobal();
				 
				
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
							if(isGlobal) {
								nt->setOffset(0);
								if(nt->size)
								{
									allVariables.push_back(nt->name + " dw " + to_string(nt->size) + "dup(?)");
								}
								else{
									allVariables.push_back(nt->name + " dw ? ");	
								}
							}
							else {
								if(nt->size)
								{
									offset += nt->size * 2;
									nt->setOffset(offset);
								}
								else {
									nt->setOffset(nextOffset());
									
								}
							}
							
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
				
				/* code section */
				$$->code = $2->code;
				
			
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
				
				/* code section */
				$$->code = $2->code;
				
				
			}
			
;
statements:		statement
			{
				logRule("statements", "statement");
				$$ = new nonTerminal("", "statements");
				$$->addNextChild($1);
				
				logPattern($$);
				
				/*code section */
				$$->code = $1->code;
				
				
			}
|			statements statement
			{
				logRule("statements", "statements statement");
				$$ = $1;
				$$->addNextChild($2);
				
				logPattern($$);
				
				/* code section */
				$$->code = $1->code + $2->code;
			}
;
statement: 		var_declaration
			{
				logRule("statement", "var_declaration");
				
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
				/*code section*/
				$$->code = $1->code;
				
			}
| 			expression_statement
			{
				logRule("statement", "expression_statement");
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
				/*code section*/
				$$->code = $1->code;
				
			}
| 			compound_statement
			{
				logRule("statement", "compound_statement");
				$$ = new nonTerminal("", "statement");
				$$->addNextChild($1);
				$$ = $1;
				logPattern($$);
				
				/*code section*/
				$$->code = $1->code;
				
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
				
				
				/* code section */
				$$->code = $3->code;
				string label1 = newLabel();
				string label2 = newLabel();
				$$->code += "\t; for \n";
				$$->code += "\t" + label1 + ":\n";
				$$->code +=  $4->code;
				$$->code += "\tcmp " + getWordPosition($4) +", 0\n";
				$$->code += "\tje " + label2 +"\n";
				$$->code += $7->code;
				$$->code += $5->code;
				$$->code += "\tjmp " + label1 + "\n";
				$$->code += "\t" + label2 + ":\n";
				
				
				
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
				
				/* code section */
				string label = newLabel();
				$$->code = $3->code;
				$$->code += "\t; if then\n";
				$$->code += "\tcmp " + getWordPosition($3) + ", 0\n";
				$$->code += "\tje " + label + "\n";
				$$->code += $5->code;
				$$->code += "\t" + label + ":\n";
				
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
				
				/* code section */
				string label = newLabel();
				string label2 = newLabel();
				$$->code = $3->code;
				$$->code += "\t; if\n";
				$$->code += "\tcmp " + getWordPosition($3) + ", 0\n";
				$$->code += "\tje " + label + "\n";
				$$->code += $5->code;
				$$->code += "\tjmp " + label2 + "\n";
				
				
				$$->code += "\t; else\n";
				$$->code += "\t" + label + ":\n";
				$$->code += $7->code;
				$$->code += "\t" + label2 + ":\n";
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
				
				/* code section */
				
				string label1 = newLabel();
				string label2 = newLabel();
				$$->code = "\t;while \n";
				$$->code += "\t" + label1 + ":\n";
				$$->code += $3->code;
				$$->code += "\tcmp " + getWordPosition($3) + ", 0\n";
				$$->code += "\tje " + label2 + "\n";
				$$->code +=  $5->code;
				$$->code += "\tjmp " + label1 + "\n";
				$$->code += "\t" + label2 + ":\n";
				
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
				
				
				
				/* code section */
				
				$$->code = "\t; " + $$->getTerminals() + "\n";
				$$->code += "\tmov ax, " + getWordPosition($3) + "\n";
				$$->code += "\tpush ax\n";
				$$->code += "\tcall print\n";
				$$->code += "\tadd sp, 2\n";
				
				
			}
| 			RETURN expression SEMICOLON
			{
				$$ = new nonTerminal("", "statement");
				
				$$->addNextChild($1);
				$$->addNextChild($2);
				$$->addNextChild($3);
				
				
				logRule("statement", "RETURN expression SEMICOLON");
				logPattern($$);
				
				
				/*code section*/
				$$->code = $2->code;
				$$->code += "\tmov ax, " + getWordPosition($2) + "\n";
				$$->code += "\tjmp ret_" + currentFunction + "\n";
				
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
				
				/*code section*/
				$$->code = $1->code;
				$$->offset = $1->offset;
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
				
				$$->offset = $1->offset;
				
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
				
				
				/* code section */
				$$->arrayIndexAddress = nextOffset(); // will hold index address
				
				$$->code = "\t;" +  $$->getTerminals() +"\n";
				$$->code += $3->code;
				
				$$->code += "\tmov bx, " + getWordPosition($3) + "\n";
				$$->code += "\tadd bx, bx\n";
				
				if($1->offset == 0)
				{
					// global array
					$$->code += "\tmov word ptr[bp - " + to_string($$->arrayIndexAddress) + "], bx\n";
				}
				else
				{
					// local array
					$$->code += "\tmov ax, " + to_string($1->offset) + "\n";
					$$->code += "\tsub ax, bx\n";
					$$->code += "\tmov word ptr[bp - " + to_string($$->arrayIndexAddress) + "], ax\n";
				
				}
				
				$$->name = $1->name;
				$$->offset = $1->offset;
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
				$$->offset = $1->offset;
				$$->typeSpecifier = $1->typeSpecifier;
				
				/*code section*/
				$$->code = $1->code;
				
				
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
				
				
				/* code section */
				
				$$->code = $3->code;
				$$->code += $1->code;
				$$->code += "\t; " + $$->getTerminals() + "\n";
				
				if($1->size){ // array
				
					$$->code += "\tmov ax, " + getWordPosition($3) + "\n";
					$$->code += "\tmov bx, word ptr[bp - " + to_string($1->arrayIndexAddress) + "]\n";
					
					if($1->offset == 0)
					{
						// global array
						$$->code += "\tmov " + getWordPosition($1) + "[bx], ax\n";
					}
					else 
					{
						$$->code += "\tpush bp\n";
						$$->code += "\tsub bp, bx\n";
						$$->code += "\tmov word ptr[bp], ax\n";
						$$->code += "\tpop bp\n";
					}
					
					
					
				}
				else{
					$$->code += "\tmov ax, " + getWordPosition($3) + "\n";
					$$->code += "\tmov " + getWordPosition($1) + ", ax\n";
				
				}
				
				
			}	
;			
logic_expression: 	rel_expression
			{
				logRule("logic_expression", "rel_expression");
				$$ = new nonTerminal("", "logic_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->offset = $1->offset;
				$$->typeSpecifier = $1->typeSpecifier;
				
				/*code section*/
				$$->code = $1->code;
				
				
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
				
				/* code section */
				
				$$->code = $1->code;
				$$->code += $3->code;
				$$->code += "\t; " + $$->getTerminals()  + "\n";
				
				
				string setlabel = newLabel();
				string nextlabel = newLabel();
				$$->offset = nextOffset();
				
				
				if($2->name == "&&")
				{
					$$->code += "\tcmp " + getWordPosition($1) + ", 0\n";
					$$->code += "\tje " + setlabel + "\n";
					$$->code += "\tcmp " + getWordPosition($3) + ", 0\n";
					$$->code += "\tje " + setlabel + "\n";
					$$->code += "\tmov " + getWordPosition($$) + ", 1\n";
					$$->code += "\tjmp " + nextlabel + "\n";
					$$->code += "\t" + setlabel + ":\n";
					$$->code += "\tmov " + getWordPosition($$) + ", 0\n";
				}
				else 
				{
					$$->code += "\tcmp " + getWordPosition($1) + ", 0\n";
					$$->code += "\tjne " + setlabel + "\n";
					$$->code += "\tcmp " + getWordPosition($3) + ", 0\n";
					$$->code += "\tjne " + setlabel + "\n";
					$$->code += "\tmov " + getWordPosition($$) + ", 0\n";
					$$->code += "\tjmp " + nextlabel + "\n";
					$$->code += "\t" + setlabel + ":\n";
					$$->code += "\tmov " + getWordPosition($$) + ", 1\n";
				}
				
				$$->code += "\t" + nextlabel + ":\n";
				
			}
		
;			
rel_expression: 	simple_expression 
			{
				logRule("rel_expression", "simple_expression");
				$$ = new nonTerminal("", "rel_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->offset = $1->offset;
				$$->typeSpecifier = $1->typeSpecifier;
				
				/*code section*/
				$$->code = $1->code;
				
				
				
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
				
				/* code section */
				$$->offset = nextOffset();
				string one = newLabel();
				string nxt = newLabel();
				
				
				$$->code = $1->code;
				$$->code += $3->code;
				$$->code += "\t; " + $$->getTerminals() +  "\n";
				
				$$->code += "\tmov ax, " + getWordPosition($1) + "\n";
				$$->code += "\tcmp ax, " + getWordPosition($3) + "\n";
				
				if($2->name == "<")
				{
					$$->code += "\tjl " + one + "\n";
				
				}
				else if($2->name == ">")
				{
					$$->code += "\tjg " + one + "\n";
				
				}
				else if($2->name == "<=")
				{
					$$->code += "\tjle " + one + "\n";
				
				}
				else if($2->name == ">=")
				{
					$$->code += "\tjge " + one + "\n";
				
				}
				else if($2->name == "==")
				{
					$$->code += "\tje " + one + "\n";
				
				}
				else if($2->name == "!=")
				{
					$$->code += "\tjne " + one + "\n";
				}
				$$->code += "\tmov " + getWordPosition($$) + ", 0\n";
				$$->code += "\tjmp " + nxt + "\n";
				$$->code += "\t" + one + ":\n";
				$$->code += "\tmov " + getWordPosition($$) + ", 1\n";
				$$->code += "\t" + nxt + ":\n";
				
				
			}	
;				
simple_expression: 	term 
			{
				logRule("simple_expression", "term");
				$$ = new nonTerminal("", "simple_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->offset = $1->offset;
				$$->typeSpecifier = $1->typeSpecifier;
				
				/*code section*/
				$$->code = $1->code;
				
				
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
				
				/* code section */
				$$->offset = nextOffset();
				
				$$->code = $1->code;
				$$->code += $3->code;
				$$->code += "\t; " + $$->getTerminals()+ "\n";
				
				$$->code += "\tmov ax, " + getWordPosition($1) + "\n";
				if($2->name == "+")
				{
					$$->code += "\tadd ax, " + getWordPosition($3)+ "\n";
				}
				else 
				{
					$$->code += "\tsub ax, " + getWordPosition($3) + "\n";
				}
				$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
				
			}
;					
term:			unary_expression
			{
				
				logRule("term", "unary_expression");
				$$ = new nonTerminal("", "term");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->name = $1->name;
				$$->offset = $1->offset;
				$$->typeSpecifier = $1->typeSpecifier;
				
				/*code section*/
				$$->code = $1->code;
				
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
					
				/* code section */
				$$->offset = nextOffset();
				
				$$->code = $1->code;
				$$->code += $3->code;
				$$->code += "\t; " + $$->getTerminals()  + "\n";
				
				$$->code += "\tmov ax, " + getWordPosition($1) + "\n";
				$$->code += "\tmov bx, " + getWordPosition($3) + "\n";
				if($2->name == "*")
				{
					$$->code += "\tmul bx\n";
					$$->code += "\tmov " + getWordPosition($$) + ", ax\n"; 
				}
				else if($2->name == "%")
				{
					$$->code += "\txor dx, dx\n";
					$$->code += "\tdiv bx\n";
					$$->code += "\tmov " + getWordPosition($$) + ", dx\n";
				}
				else 
				{
					$$->code += "\txor dx, dx\n";
					$$->code += "\tdiv bx\n";
					$$->code += "\tmov " + getWordPosition($$) + ", ax\n";

				}
				
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
				
				/* code section */
				
				
				$$->code = $2->code;
				$$->code += "\t; "  + $$->getTerminals() + "\n";
				
				if($1->name == "+")
				{
					$$->offset = $2->offset;
					$$->name = $2->name;
				}
				else 
				{
					$$->offset = nextOffset();
					$$->code += "\tmov ax, " + getWordPosition($2) + "\n";
					$$->code += "\tneg ax\n";
					$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
				}
				
				
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
				
				/* code section */
				
				string one = newLabel();
				string label2 = newLabel();
				
				$$->offset = nextOffset();
				
				$$->code = $2->code;
				$$->code += "\t; " + $$->getTerminals() + "\n";
				
				$$->code += "\tmov ax, " + getWordPosition($2) + "\n";
				
				$$->code += "\tcmp ax, 0\n";
				$$->code += "\tje " + one + "\n";
				$$->code += "\tmov " + getWordPosition($$) + ", 0\n";
				$$->code += "\tjmp " + label2 + "\n";
				$$->code += "\t" + one + ":\n";
				$$->code += "\tmov " + getWordPosition($$) + ", 1\n";
				$$->code += "\t" + label2 + ":\n";
				
				
				
			}
| 			factor 
			{
				logRule("unary_expression", "factor");
				$$ = new nonTerminal("", "unary_expression");
				$$->addNextChild($1);
				
				logPattern($$);
				
				$$->typeSpecifier = $1->typeSpecifier;
				$$->name = $1->name;
				$$->offset = $1->offset;
				
				/*code section*/
				$$->code = $1->code;
				
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
				
				/* code section */
				$$->code = $1->code;
				if($1->size){ // array
				
					$$->offset = nextOffset();
					
					$$->code += "\tmov bx, word ptr[bp - " + to_string($1->arrayIndexAddress) + "]\n";
					
					if($1->offset == 0)
					{
						// global array
						$$->code += "\tmov ax, " + getWordPosition($1) + "[bx]\n";
						$$->code += "\tmov " + getWordPosition($$) + ", ax\n";

					}
					else 
					{
						// local array
						
						$$->code += "\tpush bp\n";
						$$->code += "\tsub bp, bx\n";
						$$->code += "\tmov ax, word ptr[bp]\n";
						$$->code += "\tpop bp\n";
						$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
					
					}
					
					
					
				}
				else{
					$$->offset = $1->offset;
				}
				
				
				
				
				
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
				
				$$->code = $3->code;
				
				
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
							$$->code += "\tpush " + getWordPosition(argument) + "\n";
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
				
				/* code section */
				
				
				
				$$->code += "\tcall " + $1->name + "\n";
				$$->code += "\tadd sp, " + to_string(arg_cnt * 2) + "\n";
				$$->offset = nextOffset();
				$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
				
				
				
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
				
				/* code section */
				$$->code = $2->code;
				$$->name = $2->name;
				$$->offset = $2->offset;
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
				
				/* code section */
				$$->code = $1->code;
				$$->code += "\t; " + $$->getTerminals() + "\n";
				
				$$->offset = nextOffset();
				
				
				if($1->size){ // array
				
				
					$$->code += "\tmov bx, word ptr[bp - " + to_string($1->arrayIndexAddress) + "]\n";
					if($1->offset == 0)
					{
						$$->code += "\tmov ax, " + getWordPosition($1) + "[bx]\n";
						$$->code += "\tinc " + getWordPosition($1) + "[bx]\n";
						$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
					}
					else {
						$$->code += "\tpush bp\n";
						$$->code += "\tsub bp, bx\n";
						$$->code += "\tmov ax, word ptr[bp]\n";
						$$->code += "\tmov bx, ax\n";
						$$->code += "\tadd ax, 1\n";
						$$->code += "\tmov word ptr[bp], ax\n";
						$$->code += "\tpop bp\n";
						$$->code += "\tmov " + getWordPosition($$) + ", bx\n";
					}
					
					
				}
				else{
					$$->code += "\tmov ax, " + getWordPosition($1) + "\n";
					$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
					$$->code += "\tadd ax, 1\n";
					$$->code += "\tmov " + getWordPosition($1) + ", ax\n";
				
				}
				
				
								
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
				
				/* code section */
				$$->code = $1->code;
				$$->code += "\t; " + $$->getTerminals() + "\n";
				
				$$->offset = nextOffset();
				
				
				if($1->size){ // array
				
					$$->code += "\tmov bx, word ptr[bp - " + to_string($1->arrayIndexAddress) + "]\n";
					if($1->offset == 0)
					{
						$$->code += "\tmov ax, " + getWordPosition($1) + "[bx]\n";
						$$->code += "\tdec " + getWordPosition($1) + "[bx]\n";
						$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
					}
					else {
						$$->code += "\tpush bp\n";
						$$->code += "\tsub bp, bx\n";
						$$->code += "\tmov ax, word ptr[bp]\n";
						$$->code += "\tmov bx, ax\n";
						$$->code += "\tsub ax, 1\n";
						$$->code += "\tmov word ptr[bp], ax\n";
						$$->code += "\tpop bp\n";
						$$->code += "\tmov " + getWordPosition($$) + ", bx\n";
					}
					
				}
				else{
					$$->code += "\tmov ax, " + getWordPosition($1) + "\n";
					$$->code += "\tmov " + getWordPosition($$) + ", ax\n";
					$$->code += "\tsub ax, 1\n";
					$$->code += "\tmov " + getWordPosition($1) + ", ax\n";
				}
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
				
				/* code section */
				$$->code = $1->code + $3->code;
				
				
				
			}
|			logic_expression
			{
				logRule("arguments", "logic_expression");
				
				$$ = new nonTerminal("", "arguments");
				$$->addNextChild($1);
				logPattern($$);
				
				/* code section */
				
				$$->code = $1->code;
				
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
	
	asmFile.open("code.asm", ios::out);
	optimizedasmFile.open("optimized_code.asm", ios::out);
	
	
	
	table = new symbolTable(30);
	yyparse();
	
	
	table->print("A");
	cout << "Total Lines: " << line_count << endl;
	cout << "Total Errors: " << error_count << endl << endl;
	
	
	errorFile.close();
	fclose(yyin);


}
