/*****************************
   	Richard Evans - RCE10
   	Language Processors
   	Pascal -> ARM Compiler
****************************/


%{ 
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <cmath>
#include "token.h"

#define YYDEBUG 1

using namespace std;

void yyerror(const char *s);
int yylex();
extern FILE* yyin;

//Declare Global Variables and Structures
string programName;
string memAddress;
int varsDecIndex = 0;
int varsDeclared = 0;
bool trackChanges = false;
int loopVarReg = 0;
int regToChange = 1;
int functionIndex = 0;

//Initial User Memory Address Hex
int memPointer = 100;
int labelCount = 1;

//Counters For Error Returning
int col, row = 1;

//Struct for Register Information
typedef struct {
	string rName;
	string varName;
	bool used;
} reg;

//Struct for Variable Information
typedef struct {
	string vName;
	string vType;
	string vAddress;
	bool inUse;
	bool constant;
} variable;

//Struct for Function Information
typedef struct{
	string fName;
	string labelName;
	string inputName;
	int	functionRegister;
	string inputType;
	string rType;
} function;

//Struct for Tracking Changes
typedef struct{
	string varChanged;
	int originalReg;
} changeTrack;

//Temporary change Variable to be pushed into vector changesTracked
changeTrack tempChange;

// Functions Writing Provided Header Code to Output
void compilerHead();
void writeFName(string);
void writeStart();
void writeFooter();
void stdlibFunction(string, string);
void armWrite(string);

//Structures for Emulating ARM Hardware Registers
//R0 used for PRINTR0_ function
//R11 used for Memory Address Access
//R12 Temporary Calculation Register
//R13 Stack Pointer
//R14 Link Register
//R15 Program Counter
reg regBank[16];

//Array of Functions
function functionList[10];

//Array of Variables
variable varList[50];

//Vector for Tracking Changes in Loops where Registers are Changed
vector<changeTrack> changesTracked;

//Stacks for Writing IfThen/IfThenElse/While/For Statements
vector<string> startLabelStack;
vector<string> exitLabelStack;
vector<string> branchStack;

//Stream used for Errors
stringstream errors;
//Stream used for Output
ofstream output;

string tempstring;

//Utility functions ---------------------
void initialiseRegBank();

void declareConstant(string);
int declareVar(string);

void outputRegBank();
void outputVarList();
void outputFuncList();

void createVar(string);

bool isInt(double);
bool varCheck(string);
bool functionCheck(string);
bool varDecCheck(string);
bool varCheck(string, string);
bool numCheck(const string &);
void constantCheck(string);

void writeCompare(string, string, string);
string invCond(string);
void writeStartLabel();
void writeLabel();
void writeThenExitLabel();
void writeExitLabel();
void writeJMP();
void writeLoop();
void incrementVar(string);

bool checkFunctionArg(string, string);
bool checkTypeMatch(string, string);
string getFunctionLabel(string);
int getFunctionRegister(string);
string getFunctionInput(string);

void writeBL(string);
void saveRegisters();
void restoreRegisters();

void writeFunctionLabel(string);
void setLabelName(string);
void setMemAddress(string);
void setAssignment(string, string);

string addOp(string, string);
string subOp(string, string);
string mulOp(string, string);
string divOp(string, string);

int getRegister(string);
bool inRegister(string);
int moveToRegister(string);
void swapReg(int, int);
void swapRegARM(int, int);
void revertChanges();

//Grammar Definitiions
%}

//Token Declarations
%token PROGRAM VAR FUNCTION START END CONST
%token IDENTIFIER INT INTEGER STRING BOOLEAN 
%token IF THEN ELSE FOR TO DO WHILE

%token WRITE

%token LBRAC RBRAC LSBRAC RSBRAC
%token ADD SUB MUL DIV
%token EQ NE GT GE LT LE AND OR NOT
%token ASSIGN COLON SEMICOLON COMMA DOT
%token ARRAY OF TYPE

%%
//Grammar Rules
program:
	program_header program_body
	;

program_header:
	program_name declaration_list
	;
	
//Once Program Declaration Found Output to Top of Output
program_name:
	PROGRAM p_id SEMICOLON	{writeFName($2->getValue()); programName=$2->getValue();}
	;

//Program Name
p_id:
	IDENTIFIER {$$ = new Token(bridge->getValue());}
	;

//List of Declarations at Top of Program
declaration_list:
	declaration_list declaration
	| declaration
	;

//Types of Declarations
declaration:
	variable_declaration_block
	| function_declaration_block
	| constant_declaration_block
	;

//Variable Declaration Section
variable_declaration_block:
	VAR variable_declaration_list
	;

//List of Variables Declarations
variable_declaration_list:
	variable_declaration_list variable_declaration
	| variable_declaration
	;

//Formal Variable Declaration
//Create an Element in Variable Array for Each Variable and Set Type
//Maintains Memory Address Pointer
variable_declaration:
	variable_list COLON type SEMICOLON	{for(int i = varsDecIndex; i < varsDecIndex+varsDeclared; i++){varList[i].vType = ($3->getValue());}; varsDecIndex = varsDecIndex+varsDeclared; varsDeclared = 0;}
	;

//List of Variable Names
variable_list:
	variable_list COMMA variable
	| variable	{$$ = $1;}
	;

//Variable Name
variable:
	IDENTIFIER	{$$ = new Token(bridge->getValue()); if(varDecCheck(bridge->getValue()) == 1){createVar(bridge->getValue());};}
	;
	
	
//Variable Allowed Types (Uses for String and Boolean not Supported)
type:
	INTEGER {$$ = new Token(bridge->getValue());}
	| STRING {$$ = new Token(bridge->getValue());}
	| BOOLEAN {$$ = new Token(bridge->getValue());}
	;

//Function Declaration Section
function_declaration_block:
	function_declaration_head function_body SEMICOLON
	;

//Function Declaration Header - Functions Must Be Defined In Their Own FUNCTION Section	
function_declaration_head:
	FUNCTION func_name {functionList[functionIndex].fName = ($2->getValue()); setLabelName($2->getValue()); writeFunctionLabel($2->getValue()); saveRegisters();} LBRAC input_variable_declaration RBRAC {;} COLON type SEMICOLON {functionList[functionIndex].rType = ($9->getValue()); functionList[functionIndex].functionRegister = functionIndex+1; functionIndex++;}
	;

//Function Name
func_name:
	IDENTIFIER	{$$ = new Token(bridge->getValue());}
	;

//Input Variables for Function
//Sets Elements in Function	List Array
input_variable_declaration:
	variable COLON type	{for(int i = varsDecIndex; i < varsDecIndex+varsDeclared; i++){varList[i].vType = ($3->getValue()); functionList[functionIndex].inputName = $1->getValue(); functionList[functionIndex].inputType = $3->getValue(); varList[i].vType = ($3->getValue());}; varsDecIndex = varsDecIndex+varsDeclared; varsDeclared = 0; {if(inRegister($1->getValue())){regToChange = functionIndex+1; swapReg(getRegister($1->getValue()), regToChange);}else{regToChange = functionIndex+1; moveToRegister($1->getValue());};};}
	;

//Main Lines Of Code For Function	
function_body:
	START program_lines {restoreRegisters();} END
	;
	
//Constant Declaration Section
constant_declaration_block:
	CONST constant_declaration_list
	;

//List of Constant Declarations
constant_declaration_list:
	constant_declaration_list constant_declaration
	| constant_declaration
	;

//Constant Declaration and Initialiser
constant_declaration:
	variable EQ expression SEMICOLON {$$ = $1; varsDecIndex = varsDecIndex+varsDeclared; varsDeclared = 0; varList[varsDecIndex-1].constant = true; varList[varsDecIndex-1].vType = "INTEGER"; if(inRegister($1->getValue())){setAssignment($1->getValue(), $3->getValue());}else{moveToRegister($1->getValue()); setAssignment($1->getValue(), $3->getValue());};}
	;

//Body of Main Program
program_body:
	START {writeStart(); regToChange = functionIndex;} program_lines end
	;

//List of Lines in Main Program
program_lines:
	program_lines line
	| line
	;

//Types of Instruction Supported in Body of Code
line:
	assignment SEMICOLON
	| write_command SEMICOLON
	| if_statement SEMICOLON
	| ifThenElse_statement SEMICOLON
	| for_loop SEMICOLON
	| while_loop SEMICOLON
	;

//Definition of Assignment
assignment:
	var ASSIGN expression {$$ = $1; constantCheck($1->getValue()); if(checkTypeMatch($1->getValue(), $3->getValue())){if(inRegister($1->getValue())){setAssignment($1->getValue(), $3->getValue());}else{moveToRegister($1->getValue()); setAssignment($1->getValue(), $3->getValue());};};}
	;

//Definition of Write Instruction
write_command:
	WRITE LBRAC var RBRAC	{armWrite($3->getValue());}
	;

//Defininition of IF Statement
if_statement:
	IF boolean THEN ifcommand {writeExitLabel();}
	;

//Defininition of IF THEN ELSE Statement
ifThenElse_statement:
	IF boolean THEN ifcommand {writeJMP(); writeThenExitLabel();} ELSE ifcommand {writeExitLabel();}
	;

//List of Instructions for IF Statements
ifcommand_list:
	ifcommand_list ifcommand SEMICOLON
	| ifcommand SEMICOLON
	;

//Statements That Can Be Executed Within IF THEN/IF THEN ELSE/WHILE/FOR Statements
ifcommand:
	assignment
	| write_command
	| if_statement
	| for_loop
	| while_loop
	| START ifcommand_list END
	;

//Boolean Expression To Be Evaluated
boolean:
	boolean_expression
	| LBRAC boolean RBRAC
	;

//Expression To Be Evaluated
boolean_expression:
	var comparator factor {writeCompare($1->getValue(), $2->getValue(), $3->getValue()); delete $1; delete $2; delete $3;}
	;

//Conditions of Evaluation
comparator:
	EQ		{$$ = new Token("EQ");}
	| NE	{$$ = new Token("NE");}
	| GT	{$$ = new Token("GT");}
	| GE	{$$ = new Token("GE");}
	| LT	{$$ = new Token("LT");}
	| LE	{$$ = new Token("LE");}
	;

//Definintion of FOR Loop
for_loop:
	FOR assignment TO factor {regToChange = getRegister($2->getValue())+1; writeStartLabel(); trackChanges = true; writeCompare($2->getValue(), "NE", $4->getValue());} DO START program_lines {revertChanges(); incrementVar($2->getValue()); writeLoop(); writeExitLabel();} END
	;
	
//Definition of WHILE Loop
while_loop:
	WHILE LBRAC {writeStartLabel(); trackChanges = true;} boolean RBRAC DO START program_lines {revertChanges(); writeLoop(); writeExitLabel();} END
	;

//Definition of Expression
expression:
	expression ADD term		{$$ = new Token(addOp($1->getValue(), $3->getValue())); delete $1; delete $3;}
	| expression SUB term	{$$ = new Token(subOp($1->getValue(), $3->getValue())); delete $1; delete $3;}
	| term	{$$ = $1;}
	| function_call			{$$ = $1; writeBL(getFunctionLabel($1->getValue()));}
	;

//Definition of Call To Function
function_call:
	var LBRAC var RBRAC	{$$ = $1; if(checkFunctionArg($1->getValue(), $3->getValue())){if(inRegister($1->getValue())){if(getRegister($1->getValue()) != getFunctionRegister($1->getValue())){swapRegARM(getRegister($1->getValue()), getFunctionRegister($1->getValue()));};} setAssignment($1->getValue(), $3->getValue());}; delete $3;}
	;

//Definition of Tier 2 Expression
term:
	expression MUL factor	{$$ = new Token(mulOp($1->getValue(), $3->getValue())); delete $1; delete $3;}
	| expression DIV factor	{$$ = new Token(divOp($1->getValue(), $3->getValue())); delete $1; delete $3;}
	| factor {$$ = $1;}
	;

//Definition of Factor
factor:
	LBRAC expression RBRAC {$$ = $2;}
	| IDENTIFIER {$$ = new Token(bridge->getValue()); if(varCheck(bridge->getValue()) && !inRegister(bridge->getValue())){if(trackChanges==true){tempChange.varChanged = regBank[regToChange].varName; tempChange.originalReg = getRegister(regBank[regToChange].varName); changesTracked.push_back(tempChange); moveToRegister(bridge->getValue());}else{moveToRegister(bridge->getValue());};};}
	| INT {$$ = new Token(bridge->getValue());}
	;

//Definition of Variable Used in Code	
var:
	IDENTIFIER {if(varCheck(bridge->getValue())){$$ = new Token(bridge->getValue()); if(!inRegister(bridge->getValue())){if(trackChanges == true){tempChange.varChanged = regBank[regToChange].varName; tempChange.originalReg = getRegister(regBank[regToChange].varName); changesTracked.push_back(tempChange); moveToRegister(bridge->getValue());}else{moveToRegister(bridge->getValue());};};}else{$$ = new Token(getFunctionInput(bridge->getValue()));};}
	;

//Definition of End of Pascal File
end:
	END DOT {writeFooter();}

%%

//Token for Passing Data From Lex To Bison
Token *bridge=NULL;

int main(int argc, char *argv[]) {

	//Write Provided Header For Output File
	compilerHead();
	//Get File Input From User Terminal Command
	yyin = fopen(argv[1], "r"); 
	//yydebug = 1;
	
	initialiseRegBank();
	
	//Open Output File
	output.open("output.s");

	//Call Lex to Begin Parsing
	yyparse();
	//Close Output Once Finished
	output.close();
	
	//Output Results To User
	cout << endl;
	cout << "------------------------------------------------" << endl;
	cout << "FINAL STATES:" << endl;
	outputRegBank();
	cout << endl;
	outputVarList();
	cout << endl;
	outputFuncList();
	
	return EXIT_SUCCESS;
}

//Function to Provide User with Detail of Error Encountered in their Pascal Code
//INPUT: Error Message To Supplement Error Location Provided Here
void yyerror(const char *s) {
	cout << endl << 
		"------------------------------------------------" << endl
		<< endl << "Error on line (" << row << "), at position (" << col << "): " << s << endl << "------------------------------------------------" << endl;
	//Terminate Program Execution - No Further Processing
	exit(1);
}

//Function to Initialise Register Bank
//INPUT: None
void initialiseRegBank() {
	for (int i=0; i<=15; i++) {
		stringstream regNo;
		regNo << "R" << i;
		regBank[i].rName = regNo.str();
		//Registers for Variables
		if((1 <= i) && (i <= 10))
		{
			regBank[i].used = 0;
			regBank[i].varName = "NULL";
			output << "	MOV	R" << i << ", #0" << endl;
		}
		//Print Register
		else if(i == 0){
			regBank[i].used = 1;
			regBank[i].varName = "PRINTREG";
		}
		//Memory Address Register
		else if(i == 11)
		{
			regBank[i].used = 1;
			regBank[i].varName = "MEMSTORE";
		}
		//Temporary Calculation Register
		else if(i == 12)
		{
			regBank[i].used = 1;
			regBank[i].varName = "OPREG";
		}
		//Private Register (Link Register, Program Counter)
		else
		{
			regBank[i].used = 1;
			regBank[i].varName = "RESERVED";
		}
	}
}

//Function That Checks Whether a Provided Variable Has Already Been Declared
//INPUT: Variable Name
bool varDecCheck(string var) {
	//Check Register Bank for 
	for(int i=0; i <= varsDeclared+varsDecIndex; i++){
		if (varList[i].vName == var) {
			errors << "variable Redeclaration: " << var << endl;
			errors << "you must use a unique variable name" << endl;
			yyerror((errors.str()).c_str());
			return 0;
		}
	}
	return 1;
}

//Function To Output Contents Of Register Bank To User
//INPUT: None
void outputRegBank() {
	for(int i=0; i<=15; i++) {
			cout << regBank[i].rName << " " << regBank[i].varName
				<< " "	<< regBank[i].used << endl;
		}
}

//Function To Output Variables Declared To User
//INPUT: None
void outputVarList() {
	for (int i=0; i < varsDecIndex; i++) {
		cout << varList[i].vName << " " << varList[i].vType << " " << varList[i].vAddress << endl;
	}
}

//Function to Output List of Declared Functions To User
//INPUT: None
void outputFuncList(){
	for(int i = 0; i < functionIndex; i++)
		cout << functionList[i].fName << " " << functionList[i].labelName << " " << functionList[i].inputName << " " << functionList[i].rType << endl;
}

//Function To Declare a Variable
//INPUT: Variable Name
void createVar(string var){
	varList[varsDecIndex+varsDeclared].vName = var;
	varList[varsDecIndex+varsDeclared].inUse = true;
	setMemAddress(var); 
	declareVar(var);
	varsDeclared++;
}

//Function To Set The Memory Address Of A Variable and Increment Memory Address Pointer
//INPUT: Variable Name
void setMemAddress(string var){
	stringstream stream;
	stream << "0x" << memPointer;
	for(int i = 0; i <= varsDecIndex+varsDeclared; i++){
		if(varList[i].vName == var){
			varList[i].vAddress = stream.str();
			memPointer = memPointer + 4;
			break;
		}
	}
}

//Function To Declare a Variable In Registers If There Is Space
//INPUT: Variable Name
int declareVar(string var) {
	for (int i = 1; i <= 10; i++) {
		if (regBank[i].used == 0) {
			regBank[i].varName = var;
			regBank[i].used = 1;
			return 0;
		}
	}
	return 1;
}

//Function To Write A Comparison To Output File for Use in Conditional Statements
//INPUT: Variable to be Compared, Comparator, Variable To Be Compared or Number
void writeCompare(string var, string condition, string num){
	stringstream ostream, exitstream;
	//Check Variable One is Valid
	if(varCheck(var)) {
		//Variable Two is Literal
		if(numCheck(num)){
			ostream << "	CMP	R" << getRegister(var) << ", #" << num << endl;
		}
		//Variable Two is a Variable
		else if(varCheck(num)){
			ostream << "	CMP	R" << getRegister(var) << ", R" << getRegister(num) << endl;
		}
		//Else Output Error
		else{
			errors << "you haven't declared a valid comparison" << endl;
			yyerror((errors.str()).c_str());
		}
		//Output Link to Exit if Condition Fails
		ostream << "	B" << invCond(condition) << "	exitL" << labelCount-1 << "_" << endl;
		exitstream << "exitL" << labelCount-1 << "_";
		output << ostream.str();
		exitLabelStack.push_back(exitstream.str());
		labelCount++;
	}
	//Else Output Error
	else{
		errors << "you haven't declared a var to compare" << endl;
		yyerror((errors.str()).c_str());
	}
}

//Function Taking a Comparator and Returning its Logical Opposite
//INPUT: Condition
string invCond(string op) {
	if (op == "EQ")
		return "NE";
	else if (op == "NE")
		return "EQ";
	else if (op == "GT")
		return "LE";
	else if (op == "GE")
		return "LT";
	else if (op == "LT")
		return "GE";	
	else if (op == "LE")
		return "GT";
}

//Function Which Checks that the Input of a Function is the Correct Type for that Function
//INPUT: Function Name, Variable Being Passed In
bool checkFunctionArg(string functionInput, string var1){
	//Variable Being Passed Doesn't Exist
	if(!varCheck(var1)){
		errors << var1 << " is not a valid variable to pass to function with input " << functionInput << endl;
	yyerror((errors.str()).c_str());
		return false;
	}
	//Function Doesn't Exist
	else if(!varCheck(functionInput)){
		errors << "no function exists with input " << functionInput << endl;
	yyerror((errors.str()).c_str());
		return false;
	}
	else{
		for(int i = 0; i < functionIndex; i++){
			if(functionList[i].inputName == functionInput){
				for(int j = 0; j < varsDeclared+varsDecIndex; j++){
					if(varList[j].vName == var1){
						//Function Input Type Doesn't Match
						if(functionList[i].inputType != varList[j].vType){
							errors << "Invalid function call to function with input " << functionInput << ", as " << var1 << " does not match argument type" << endl;
	yyerror((errors.str()).c_str());
							return false;
						}
						else
							return true;
					}
				}
			}
		}
	}
}

//Function Checking if the Types of Two Variables Agree
//INPUT: Two Variable Tames
bool checkTypeMatch(string var1, string var2){
	//Both Variables Exist
	if(varCheck(var1, var2)){
		for(int i = 0; i < varsDeclared+varsDecIndex; i++){
			if(varList[i].vName == var1){
				for(int j = 0; j < varsDeclared+varsDecIndex; j++){
					if(varList[j].vName == var2){
						if(varList[i].vType == varList[j].vType){
							return true;
						}
					}
				}
			}
		}
	}
	//Second Variable is a Result From Computation
	else if((varCheck(var1)) && (var2 == "OPREG")){
		return true;
	}
	//Second Variable is a Literal
	else if((varCheck(var1)) && (numCheck(var2))){
		return true;
	}
	//Else Output Error
	errors << "Invalid variable assignment: non-matching variable types for " << var1 << " " << var2 << endl;
	yyerror((errors.str()).c_str());
	return false;
}


//Function Which Finds and Returns the Label Name for a Declared Function
//INPUT: Function Name
string getFunctionLabel(string inputvar){
	for(int i = 0; i < functionIndex; i++){
		if(functionList[i].inputName == inputvar)
			return functionList[i].labelName;
	}
	//Function Not Found
	errors << "getting function label, call to nonexistant function made" << endl;
	yyerror((errors.str()).c_str());
	return "NULL";
}

//Function which Finds and Returns the Register Used in the Function
//INPUT: Function Name
int getFunctionRegister(string inputvar){
	for(int i = 0; i < functionIndex; i++){
		if(functionList[i].inputName == inputvar)
			return functionList[i].functionRegister;
		}
	//Function Not Found
	errors << "getting function register, call to nonexistant function made" << endl;
	yyerror((errors.str()).c_str());
	return -1;
}

//Function which Finds and Returns the Temporary Variable used in a Function
//INPUT: Function Name
string getFunctionInput(string funcName){
	for(int i = 0; i < functionIndex; i++){
		if(functionList[i].fName == funcName){
			return functionList[i].inputName;
		}
	}
	//Function Not Found
	errors << "getting function input, call to nonexistant function " << funcName << endl;
	yyerror((errors.str()).c_str());
	return "NULL";
}

//Function to Write a New Label to Output
//INPUT: None
void writeLabel(){
	stringstream stream;
	stream << "L" << labelCount << "_	";
	output << stream.str();
	labelCount++;
}

//Function which Retrieves an Exit Label from the Back of the Stack and Outputs it
//INPUT: None
void writeExitLabel(){
	string exit;
	exit = exitLabelStack.back();
	output << exit << endl;
	exitLabelStack.pop_back();
}

//Function which outputs the Exit Label One from the Top of the Pointer, Removing it from the Stack
//	This is needed in IF THEN ELSE Statements to Maintain Order of Labels for Correct Output Code
//INPUT: None
void writeThenExitLabel(){
	string temp, exit;
	//Retrieve Top of Stack
	temp = exitLabelStack.back();
	//Retrieve One From Top of Stack
	exitLabelStack.pop_back();
	exit = exitLabelStack.back();
	output << exit << endl;
	exitLabelStack.pop_back();
	//Replace Top of Stack
	exitLabelStack.push_back(temp);
}

//Function to Output start Label and Push it to the Stack for Later Use
//INPUT: None
void writeStartLabel(){
	stringstream stream;
	stream << "startL" << labelCount << "_	";
	output << stream.str();
	startLabelStack.push_back(stream.str());
	labelCount++;
}

//Function to Write a Branch and Link Instruction
//INPUT: Label to Branch and Link To
void writeBL(string funcLabel){
	stringstream stream;
	stream << "	BL	" << funcLabel << endl;
	output << stream.str();
}

//Function to write a Jump Statement and Push the Exit onto the Stack
//INPUT: None
void writeJMP(){
	stringstream jumpexit, ostream;
	ostream << "	B	exitL" << labelCount << "_" << endl;
	jumpexit << "exitL" << labelCount << "_";
	output << ostream.str();
	exitLabelStack.push_back(jumpexit.str());
}

//Function to Write a Return to the Beginning of a Section of Exectuion and Remove Start Label
//	from Stack
//INPUT: None
void writeLoop(){
	string start;
	start = startLabelStack.back();
	output << "	B " << start << endl;
	startLabelStack.pop_back();
}

//Function to Output an Increment to a Variable
//INPUT: Variable Name
void incrementVar(string var){
	stringstream stream;
	stream << "	ADD	R" << getRegister(var) << ", R" << getRegister(var) << ", #1" << endl;
	output << stream.str();
}

//Function to Store the Link Register to Push Back to PC
//INPUT: None
void saveRegisters(){
	stringstream stream;
	stream << "	STMED	r13!,{r14}" << endl;
	output << stream.str();
}

//Function to Restore Link Register Address to PC
//INPUT: None
void restoreRegisters(){
	stringstream stream;
	stream << "	LDMED	r13!,{r15}" << endl;
	output << stream.str();
}

//Function to Swap Variables in the Registers
//INPUT: Two Registers to be Swapped
void swapReg(int reg1, int reg2){
	string temp;
	temp = regBank[reg1].varName;
	regBank[reg1].varName = regBank[reg2].varName;
	regBank[reg2].varName = temp;
}

//Function the same as Above but which Ouputs the ARM Code for the Swap
//INPUT: Two Registers to Be Swapped
void swapRegARM(int reg1, int reg2){
	reg tempReg;
	tempReg.rName = regBank[reg1].varName;
	regBank[reg1].varName = regBank[reg2].varName;
	regBank[reg2].varName = tempReg.varName;
	output << "	MOV	R12, R" << reg1 << endl;
	output << "	MOV	R" << reg1 << ", R" << reg2 << endl;
	output << "	MOV	R" << reg2 << ", R12" << endl;
}

//Function to Undo any Changes Made within a Loop to Maintain Continuity
//INPUT: None
void revertChanges(){
	for(int i = 0; i < changesTracked.size(); i++){
		regToChange = changesTracked[i].originalReg;
		moveToRegister(changesTracked[i].varChanged);
	}
	trackChanges = false;
	changesTracked.clear();
}


//Function to Write a Function Label
//INPUT: Function Name
void writeFunctionLabel(string funcName){
	stringstream stream;
	stream << funcName << "_" << endl;
	output << stream.str();
}

//Function to Set Label Names for Functions
//INPUT: Function Name
void setLabelName(string func){
	stringstream stream;
	stream << func << "_";
	for(int i = 0; i <= functionIndex; i++)
		{
			if(functionList[i].fName == func)
				functionList[i].labelName = stream.str().c_str();
		}
}

//Function to Ouput Addition Operator of Two Variables
//INPUT: Two Variables/Literals to be Added
string addOp(string s1, string s2) {
	stringstream stream, returnStream;
	if (numCheck(s1)) {
		// number(s1) + number(s2)
		if (numCheck(s2)) {
			stream << "	MOV	R12, #" << s1 << endl;
			stream << "	ADD	R12, R12, #" << s2 << endl;
		}
		// number(s1) + variable(s2)
		else {
			if(varCheck(s2)) {
				stream << "	ADD	R12, R" << getRegister(s2) << ", #" << s1 << endl;
				}
				else{
				errors << "variable " << s2 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
				}
		}
	}
	else {
		// variable(s1) + number(s2)
		if (numCheck(s2)) {
			if(varCheck(s1)) {
				stream << "	ADD	R12, R" << getRegister(s1) << ", #" << s2 << endl;
				output << stream.str();
				}
			else {
				errors << "variable " << s1 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
		// variable(s1) + variable(s2)
		else {
			if(varCheck(s1, s2)){
				stream << "	ADD	R12, R" << getRegister(s1) << ", R" << getRegister(s2) << endl;
			}
			else{
				errors << "variables " << s1 << " and " << s2 << " are not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
	}
	output << stream.str();
	return "OPREG";
}

//Function to Ouput Subtraction Operator of Two Variables
//INPUT: Two Variables/Literals to be Subtracted
string subOp(string s1, string s2) {
	stringstream stream, returnStream;
	if (numCheck(s1)) {
		// number(s1) - number(s2)
		if (numCheck(s2)) {
			stream << "	MOV	R12, #" << s1 << endl;
			stream << "	SUB	R12, R12, #" << s2 << endl;
		}
		// number(s1) - variable(s2)
		else {
			if(varCheck(s2)) {
				stream << "	RSB R12, R" << getRegister(s2) << ", #" << s1 << endl;
				}
				else{
				errors << "variable " << s2 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
				}
		}
	}
	else {
		// variable(S1) - number(S2)
		if (numCheck(s2)) {
			if(varCheck(s1)) {
				stream << "	SUB	R12, R" << getRegister(s1) << ", #" << s2 << endl;
				output << stream.str();
				}
			else {
				errors << "variable " << s1 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
		// variable(S1) - variable(S2)
		else {
			if(varCheck(s1, s2)){
				stream << "	SUB	R12, R" << getRegister(s1) << ", R" << getRegister(s2) << endl;
			}
			else{
				errors << "variables " << s1 << " and " << s2 << " are not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
	}
	output << stream.str();
	return "OPREG";
}

//Function to Ouput Multiplication Operator of Two Variables
//INPUT: Two Variables/Literals to be Multiplied
string mulOp(string s1, string s2) {
	stringstream stream, returnStream;
	if (numCheck(s1)) {
		// number(s1) * number(s2)
		if (numCheck(s2)) {
			//if s1 is 1
			if(s1 == "1"){
				stream << "	MOV	R12, #" << s2 << endl;
			}
			//if s2 is 1
			else if(s2 == "1"){
				stream << "	MOV	R12, #" << s1 << endl;
			}
			//if s1 is power of 2
			else if(isInt(log2(atoi(s1.c_str())))){
				stream << "	MOV	R12, #" << s2 << endl;
				stream << "	LSL	R12, R12, #" << log2(atoi(s1.c_str())) << endl;
			}
			//if s2 is power of 2
			else if(isInt(log2(atoi(s2.c_str())))){
				stream << "	MOV	R12, #" << s1 << endl;
				stream << "	LSL	R12, R12, #" << log2(atoi(s2.c_str())) << endl;
			}
			else{
			stream << "	MOV	R12, #" << s1 << endl;
			stream << "	MUL	R12, R12, #" << s2 << endl;
			}
		}
		// number * variable
		else if(varCheck(s2)) {
			//s1 is 1
			if(s1 == "1"){
				return s2;
			}
			//s1 is power of 2
			else if(isInt(log2(atoi(s1.c_str())))){
				stream << "	LSL	R12, R" << getRegister(s2)<< ", #" << log2(atoi(s1.c_str())) << endl;
			}
			else{
				stream << "	MUL	R12, R" << getRegister(s2) << ", #" << s1 << endl;
			}
		}
		else{
			errors << "variable " << s2 << " is not declared" << endl;
			yyerror((errors.str()).c_str());
		}
	}
	// variable(s1) * number(s2)
	else if (numCheck(s2)) {
		if(varCheck(s1)) {
			if(s2 == "1"){
				return s1;
			}
			//s2 is power of 2
			else if(isInt(log2(atoi(s2.c_str())))){
				stream << "	LSL	R12, R" << getRegister(s1)<< ", #" << log2(atoi(s2.c_str())) << endl;
			}
			else{
				stream << "	MUL	R12, R" << getRegister(s1) << ", #" << s2 << endl;
			}
		}
		else {
			errors << "variable " << s1 << " is not declared" << endl;
			yyerror((errors.str()).c_str());
		}
	}
	// variable(s1) * variable(s2)
	else if(varCheck(s1, s2)){
		stream << "	MUL	R12, R" << getRegister(s1) << ", R" << getRegister(s2) << endl;
	}
	else{
		errors << "variables " << s1 << " and " << s2 << " are not declared" << endl;
		yyerror((errors.str()).c_str());
	}
	output << stream.str();
	return "OPREG";
}

//Function to Ouput Division Operator of Two Variables - Only Supports Division by Power of 2
//INPUT: Two Variables/Literals to be Divided
string divOp(string s1, string s2) {
	stringstream stream, returnStream;
	if (numCheck(s1)) {
		// number(s1) / number(s2)
		if (numCheck(s2)) {
			//s1 is 1
			if(s1 == "1"){
				stream << "	MOV	R12, #" << s2 << endl;
			}
			//s2 is 1
			else if(s2 == "1"){
				stream << "	MOV	R12, #" << s1 << endl;
			}
			//s2 is a power of 2
			else if(isInt(log2(atoi(s2.c_str())))){
				stream << "	MOV	R12, #" << s1 << endl;
				stream << "	LSR	R12, R12, #" << log2(atoi(s2.c_str())) << endl;
			}
			//NOT SUPPORTED
			else{
			errors << "THIS OPERATION IS NOT SUPPORTED" << endl;
				yyerror((errors.str()).c_str());
			stream << "	MOV	R12, #" << s1 << endl;
			stream << "	DIV	R12, R12, #" << s2 << endl;
			}
		}
		// number(s1) / variable(s2)
		else {
			errors << "THIS OPERATION IS NOT SUPPORTED" << endl;
				yyerror((errors.str()).c_str());
			if(varCheck(s2)) {
				if(s1 == "1"){
					return s2;
				}
				else{
					stream << "	DIV	R12, R" << getRegister(s2) << ", #" << s1 << endl;
				}
			}
			else{
				errors << "variable " << s2 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
	}
	else {
		// variable(s1) / number(s2)
		if (numCheck(s2)) {
			if(varCheck(s1)) {
				if(s2 == "1"){
					return s1;
				}
				else if(isInt(log2(atoi(s2.c_str())))){
					stream << "	LSR	R12, R" << getRegister(s1)<< ", #" << log2(atoi(s2.c_str())) << endl;
				}
				else{
					errors << "THIS OPERATION IS NOT SUPPORTED" << endl;
				yyerror((errors.str()).c_str());
					stream << "	DIV	R12, R" << getRegister(s1) << ", #" << s2 << endl;
					output << stream.str();
				}
			}
			else {
				errors << "variable " << s1 << " is not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
		// variable(s1) / variable(s2)
		else {
			errors << "THIS OPERATION IS NOT SUPPORTED" << endl;
				yyerror((errors.str()).c_str());
			if(varCheck(s1, s2)){
				stream << "	DIV	R12, R" << getRegister(s1) << ", R" << getRegister(s2) << endl;
			}
			else{
				errors << "variables " << s1 << " and " << s2 << " are not declared" << endl;
				yyerror((errors.str()).c_str());
			}
		}
	}
	output << stream.str();
	return "OPREG";
}

//Function to Check if a Number is an Integer
//INPUT: Number
bool isInt(double num)
{
	if(fabs(num - (int)num) > 0.0001)
		return 0;
	else
		return 1;
}

//Function which Outputs an Assignment of two Variables
//INPUT: A Variable to be Assigned and a Number Variable/Number to Assign To
void setAssignment(string var1, string s2) {
	if (var1 == s2) {
	}
	else{
		if(numCheck(s2)) {
			if(varCheck(var1)) {
				output << "	MOV	R" << getRegister(var1) << ", #" << s2 << endl;
			}
			else if(varCheck(getFunctionInput(var1))){
				output << "	MOV	R" << getRegister(getFunctionInput(var1)) << ", #" << s2 << endl;
			}
			else {
				errors << "attempting to assign an undeclared variable " << var1 << endl;
				yyerror((errors.str()).c_str());
			}
		}
		else if(varCheck(var1, s2)) {
				output << "	MOV	R" << getRegister(var1) << ", R" << getRegister(s2) << endl;
			}
		else if(s2 == "OPREG"){
			output << "	MOV	R" << getRegister(var1) << ", R" << getRegister(s2) << endl;
		}
		else if(varCheck(getFunctionInput(var1))){
			output << "	MOV	R" << getRegister(getFunctionInput(var1)) << ", R" << getRegister(s2) << endl;
		}
		else if (varCheck(getFunctionInput(s2))){
			if(varCheck(var1)) {
				output << "	MOV	R" << getRegister(var1) << ", R" << getRegister(getFunctionInput(s2)) << endl;
			}
			else if(varCheck(getFunctionInput(var1))){
				output << "	MOV	R" << getRegister(getFunctionInput(var1)) << ", R" << getRegister(getFunctionInput(s2)) << endl;
			}
		}
		else{
				errors << "error setting assignment of " << var1 << " to " << s2 << endl;
				yyerror((errors.str()).c_str());
			}
	}
}

//Function to Check if Function if a Variable is a Constant
//INPUT: Variable Name
void constantCheck(string var){
	for(int i = 0; i < varsDecIndex+varsDeclared; i++){
		if(varList[i].vName == var){
			if(varList[i].constant == true){
				errors << "error attempting to reassign constant " << var << endl;
				yyerror((errors.str()).c_str());
			}
		}
	}
}

//Function to check if a Variable is a Number
//INPUT: Variable/Number
bool numCheck(const string &var) {
	for (int i = 0; i < var.size(); i++) {
		if (isdigit(var[i])) {
		}
		else {
			return 0;
		}
		return 1;
	}
}

//Function to Find and Return the Register a Variable is Held in
//INPUT: Variable Name
int getRegister(string var) {
	if (var == "OPREG") {
		return 12;
	}
	else {
		if (varCheck(var)) {
			for (int i=1; i<=10; i++) {
				if (regBank[i].varName == var) {
					return i;
				}
			}
		}
		errors << "error getting register of " << var << endl;
		yyerror((errors.str()).c_str());
		return -1;
	}
}

//Function to check if a Variable is in Registers
//INPUT: Variable Name
bool inRegister(string var){
	for(int i = 1; i <=10; i++){
		if(regBank[i].varName == var){
			return 1;
		}
	}
	return 0;
}

//Function to move a variable to registers if it is not in it
//INPUT: Variable Name
int moveToRegister(string var){
	//Load R11 with Variable Address then move into variable register
	if(varCheck(var)){
		for(int i = 0; i <= varsDecIndex; i++){
			if (varList[i].vName == regBank[regToChange].varName){
				output << "	MOV	R11, #" << varList[i].vAddress << endl;
				output << "	STR	R" << regToChange << ", [R11]" << endl;
				for(int j = 0; j <= varsDecIndex; j++){
					if(varList[j].vName == var){
						output << "	MOV	R11, #" << varList[j].vAddress << endl;
						output << "	LDR	R" << regToChange << ", [R11]" << endl;
						regBank[regToChange].varName = var;
						regToChange++;
						if(regToChange == 11)
							regToChange = 1;
						return 0;
					}
				}
			}
		}
		return 1;
	}
}

//Function to check if a variable has been Declared
//INPUT: Variable Name
bool varCheck(string var) {
	for (int i=0; i < varsDeclared+varsDecIndex; i++) {
		if (varList[i].vName == var) {
			return 1;
		}
	}
	return 0;
}

//Function to check if a Fuction is Declared
//INPUT: Function name
bool functionCheck(string function){
	for (int i=0; i < functionIndex; i++) {
		if (functionList[i].fName == function) {
			return 1;
		}
	}
	return 0;
}

//Function to check if two variables are declared
//INPUT: Two Variables to be Checked
bool varCheck(string var1, string var2) {
	for (int i=0; i < varsDeclared+varsDecIndex; i++) {
		if (varList[i].vName == var1) {
			for (int i=0; i < varsDeclared+varsDecIndex; i++) {
				if (varList[i].vName == var2) {
					return 1;
				}
			}
		}
	}
	return 0;
}


/*------------- DO NOT EDIT BELOW HERE----------------- */

void compilerHead(){
	cout << endl;
	cout << "/*******************************************" << endl;
	cout << "*    Pascal -> ARM Assembler Compiler      *" << endl;
	cout << "*    R.Evans                               *" << endl;
	cout << "*    ISE2                                  *" << endl;
	cout << "*    Imperial College London               *" << endl;
	cout << "*    2012                                  *" << endl;
	cout << "*******************************************/" << endl;
	cout << endl;
	cout << "// Errors Listed Below                     *" << endl;
	cout << "------------------------------------------------" << endl;
}

/********************************************************
 *		writeFName										*
 *		input: name of the program						*
 *		output: header for ARMulator					*
 ********************************************************/
void writeFName(string program_name) {
	stringstream stream;
	stream << "	AREA " << program_name << ", CODE, READONLY" << endl;
	stream << ";--------------------------------------------------------------------------------" << endl;
	stream << "; SWI constants;" << endl;
	stream << "SWI_WriteC EQU &0 ; output the character in r0 to the screen" << endl;
	stream << "SWI_Write0 EQU &2 ; Write a null (0) terminated buffer to the screen" << endl;
	stream << "SWI_ReadC EQU &4 ; input character into r0" << endl;
	stream << "SWI_Exit EQU &11 ; finish program" << endl;
	stream << "SWI_Open EQU &66 ; open a file" << endl;
	stream << "SWI_Close EQU &68 ; close a file" << endl;
	stream << "SWI_Write EQU &69 ; write to a file" << endl;
	stream << "SWI_Read EQU &6A ; read from a file" << endl;
	stream << "; Allocate memory for the stack--Used by subroutines" << endl;
	stream << ";--------------------------------------------------------------------------------" << endl;
	stream << "STACK_ % 4000 ; reserve space for stack" << endl;
	stream << "STACK_BASE ; base of downward-growing stack + 4" << endl;
	stream << "ALIGN" << endl;
	stream << endl;
	stream << "; Subroutine to print contents of register 0 in decimal" << endl;
	stream << ";--------------------------------------------------------------------------------" << endl;
	stream << "; ** REGISTER DESCRIPTION ** " << endl;
	stream << "; R0 byte to print, carry count" << endl;
	stream << "; R1 number to print " << endl;
	stream << "; R2 ... ,thousands, hundreds, tens, units" << endl;
	stream << "; R3 addresses of constants, automatically incremented" << endl;
	stream << "; R4 holds the address of units " << endl;
	stream << "; Allocate 10^9, 10^8, ... 1000, 100, 10, 1 " << endl;
	stream << endl;
	stream << "CMP1_ DCD 1000000000" << endl;
	stream << "CMP2_ DCD 100000000" << endl;
	stream << "CMP3_ DCD 10000000" << endl;
	stream << "CMP4_ DCD 1000000" << endl;
	stream << "CMP5_ DCD 100000" << endl;
	stream << "CMP6_ DCD 10000" << endl; 
	stream << "CMP7_ DCD 1000" << endl;
	stream << "CMP8_ DCD 100" << endl;
	stream << "CMP9_ DCD 10" << endl;
	stream << "CMP10_ DCD 1" << endl;
	stream << "	BL	start" << endl;
	stream << "PRINTR0_" << endl;
	stream << "	STMED	r13!,{r0-r4,r14}" << endl;
	stream << "	MOV	R1, R0" << endl;
	stream << endl;
	stream << "; Is R1 negative?" << endl;
	stream << "	CMP	R1,#0" << endl;
	stream << "	BPL	LDCONST_" << endl;
	stream << "	RSB	R1, R1, #0 ;Get 0-R1, ie positive version of r1" << endl;
	stream << "	MOV	R0, #'-'" << endl;
	stream << "	SWI	SWI_WriteC" << endl;
	stream << endl;
	stream << ";Load starting addresses" << endl;
	stream << endl;
	stream << "LDCONST_" << endl;
	stream << "	ADR	R3, CMP1_ ;Used for comparison at the end of printing" << endl;
	stream << "	ADD	R4, R3, #40 ;Determine final address (10 word addresses +4 because of post-indexing" << endl;
	stream << endl;
	stream << "; Take as many right-0's as you can..." << endl;
	stream << "NEXT0_" << endl;
	stream << "	LDR	R2, [R3], #4" << endl;
	stream << "	CMP	R2, R1" << endl;
	stream << "	BHI	NEXT0_" << endl;
	stream << endl;
	stream << ";Print all significant characters" << endl;
	stream << "NXTCHAR_" << endl;
	stream << "	MOV	R0, #0" << endl;
	stream << "SUBTRACT_" << endl;
	stream << "	CMP	R1, R2" << endl;
	stream << "	SUBPL	R1, R1, R2" << endl;
	stream << "	ADDPL	R0,R0, #1" << endl;
	stream << "	BPL	SUBTRACT_" << endl;
	stream << endl;
	stream << ";Output number of Carries" << endl;
	stream << "	ADD	R0, R0, #'0'" << endl;
	stream << "	SWI	SWI_WriteC" << endl;
	stream << endl;
	stream << "; Get next constant, ie divide R2/10" << endl;
	stream << "	LDR	R2, [R3], #4" << endl;
	stream << endl;
	stream << ";If we have gone past L10, exit function; else take next character" << endl;
	stream << "	CMP	R3, R4;" << endl;
	stream << "	BLE	NXTCHAR_;" << endl;
	stream << "; Print a line break" << endl;
	stream << "	MOV	R0, #'\\n'" << endl;
	stream << "	SWI	SWI_WriteC" << endl;
	stream << endl;
	stream << "	LDMED	r13!,{r0-r4,r15} ;Return" << endl;
	stream << ";END HEADER ---------------------------------" << endl;
	output << stream.str() << endl;
}

/********************************************************
 *		writeStart										*
 *		input: none										*
 *		output: "start" token to signal	the beginning	*
 *			of the	program								*
 ********************************************************/
void writeStart() {
	output << "	ENTRY" << endl;
	output << "start";
}

/********************************************************
 *		writeFooter										*
 *		input: none										*
 *		output: footer for ARMulator					*
 ********************************************************/
void writeFooter() {
	output << "stop";
	output << "	SWI	SWI_Exit" << endl;
	output << "	END" << endl;
}

/********************************************************
 *		stdlibFunction									*
 *		input: name, argument of the function			*
 *		output: code for standard library functions		*
 ********************************************************/
void stdlibFunction (string name, string argument) {
	if (name == "write") {
		armWrite(argument);
	}
}

/********************************************************
 *		armWrite										*
 *		input: name of the variable to output			*
 *		output: code for write to console				*
 ********************************************************/
void armWrite(string var) {
	stringstream stream;
	if(varCheck(var)){
		stream << "	MOV	R0, R" << getRegister(var) << endl;
		stream << "	BL	PRINTR0_" << endl;
		output << stream.str();
	}
	else{
		errors << "Error, " << var << " Is Not A Valid Variable to Write Out" << endl;
		yyerror((errors.str()).c_str());
	}
}
