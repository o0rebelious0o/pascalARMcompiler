%{
#include "cwy.h"
#include "token.h"
#include <iostream>
using namespace std;

extern int col;
extern int row;

%}
%option noyywrap

int				[0-9]+
char			[A-Za-z]
identifier		[A-Za-z0-9]*

A [aA]
B [bB]
C [cC]
D [dD]
E [eE]
F [fF]
G [gG]
H [hH]
I [iI]
J [jJ]
K [kK]
L [lL]
M [mM]
N [nN]
O [oO]
P [pP]
Q [qQ]
R [rR]
S [sS]
T [tT]
U [uU]
V [vV]
W [wW]
X [xX]
Y [yY]
Z [zZ]
NQUOTE [^']

%%

{A}{R}{R}{A}{Y}			{col += yyleng; return ARRAY;}
{C}{O}{N}{S}{T}			{col += yyleng; return CONST;}
{P}{R}{O}{G}{R}{A}{M}	{col += yyleng; return PROGRAM;}
{V}{A}{R}				{col += yyleng; return VAR;}
{F}{U}{N}{C}{T}{I}{O}{N} {col += yyleng; return FUNCTION;}
{B}{E}{G}{I}{N}			{col += yyleng; return START;}
{E}{N}{D}				{col += yyleng; return END;}
{T}{Y}{P}{E}			{col += yyleng; return TYPE;}
	
{I}{N}{T}{E}{G}{E}{R}	{if (bridge != NULL) delete bridge; bridge = new Token("INTEGER"); col += yyleng; return INTEGER;}
{S}{T}{R}{I}{N}{G}		{if (bridge != NULL) delete bridge; bridge = new Token("STRING"); col += yyleng; return STRING;}
{B}{O}{O}{L}{E}{A}{N}	{if (bridge != NULL) delete bridge; bridge = new Token("BOOLEAN"); col += yyleng; return BOOLEAN;}
	
{O}{F}					{col += yyleng; return OF;}
{I}{F}					{col += yyleng; return IF;}
{T}{H}{E}{N}			{col += yyleng; return THEN;}
{E}{L}{S}{E}			{col += yyleng; return ELSE;}
{F}{O}{R}				{col += yyleng; return FOR;}
{T}{O}					{col += yyleng; return TO;}
{D}{O}					{col += yyleng; return DO;}
{W}{H}{I}{L}{E}			{col += yyleng; return WHILE;}

{W}{R}{I}{T}{E}			{col += yyleng; return WRITE;}

"["						{col += yyleng; return LSBRAC;}
"]"						{col += yyleng; return RSBRAC;}
"("						{col += yyleng; return LBRAC;}
")"						{col += yyleng; return RBRAC;}
	
"+"						{col += yyleng; return ADD;}
"-"						{col += yyleng; return SUB;}
"*"						{col += yyleng; return MUL;}
"/"						{col += yyleng; return DIV;}

"="						{col += yyleng; return EQ;}
"<>"					{col += yyleng; return NE;}
">"						{col += yyleng; return GT;}
">="					{col += yyleng; return GE;}
"<"						{col += yyleng; return LT;}
"<="					{col += yyleng; return LE;}
"and"					{col += yyleng; return AND;}
"or"					{col += yyleng; return OR;}
"not"					{col += yyleng; return NOT;}


":="					{col += yyleng; return ASSIGN;}
":"						{col += yyleng; return COLON;}
";"						{col += yyleng; return SEMICOLON;}
","						{col += yyleng; return COMMA;}
"."						{col += yyleng; return DOT;}
\n						{col = 1; row++;}
[[:blank:]]				{}
"{"[^}]*"}"				{}
"//"[^\n]*(\n)			{}

	
{int}			{if (bridge != NULL) delete bridge; bridge = new Token(yytext); col += yyleng; return INT;}
{identifier}	{if (bridge != NULL) delete bridge; bridge = new Token(yytext); col += yyleng; return IDENTIFIER;}
