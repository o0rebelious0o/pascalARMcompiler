#ifndef tokenH
#define tokenH
#include <string>
using namespace std;

class Token{
public:
  Token(string);
  string getValue(void);
private:
  string value;
};

#define YY_DECL int yylex(void)
#define YYSTYPE Token *
YY_DECL;
extern YYSTYPE bridge;
#endif
