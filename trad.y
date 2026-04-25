%{                          // SECCIÓN 1 Declaraciones de C-Yacc

#include <stdio.h>
#include <ctype.h>            // declaraciones para tolower
#include <string.h>           // declaraciones para cadenas
#include <stdlib.h>           // declaraciones para exit ()

#define FF fflush(stdout);    // para forzar la impresión inmediata

int yylex () ;
int yyerror () ;
char *mi_malloc (int) ;
char *gen_code (char *) ;
char *int_to_string (int) ;
char *char_to_string (char) ;

char temp [2048] ;

// Abstract Syntax Tree (AST) Node Structure

typedef struct ASTnode t_node ;

struct ASTnode {
    char *op ;
    int type ;		// leaf, unary or binary nodes
    t_node *left ;
    t_node *right ;
} ;


// Definitions for explicit attributes

typedef struct s_attr {
    int value ;    // - Numeric value of a NUMBER 
    char *code ;   // - to pass IDENTIFIER names, and other translations 
    t_node *node ; // - for possible future use of AST
} t_attr ;

#define YYSTYPE t_attr

// ---- Tabla de variables locales ----

#define MAX_LOCALS 256

typedef struct {
    char name [256] ;
} t_local ;

t_local local_table [MAX_LOCALS] ;
int n_locals = 0 ;

char current_fun [256] = "" ;

void local_table_reset () {
    n_locals = 0 ;
}

int local_table_insert (char *name) {
    int i ;
    for (i = 0 ; i < n_locals ; i++) {
        if (strcmp (local_table [i].name, name) == 0) return 0 ; // ya existe
    }
    if (n_locals < MAX_LOCALS) {
        strcpy (local_table [n_locals++].name, name) ;
        return 1 ;
    }
    return 0 ;
}

int local_table_find (char *name) {
    int i ;
    for (i = 0 ; i < n_locals ; i++) {
        if (strcmp (local_table [i].name, name) == 0) return 1 ;
    }
    return 0 ;
}

char *resolve_var (char *name) {
    static char buf [512] ;
    if (current_fun [0] != '\0' && local_table_find (name)) {
        sprintf (buf, "%s_%s", current_fun, name) ;
        return buf ;
    }
    return name ;
}

%}

// Definitions for explicit attributes

%token NUMBER        
%token IDENTIF       // Identificador=variable
%token INTEGER       // identifica el tipo entero
%token STRING
%token MAIN          // identifica el comienzo del proc. main
%token WHILE         // identifica el bucle while
%token FOR           // identifica el bucle for
%token IF            // identifica la estructura condicional if
%token ELSE          // identifica la rama else
%token PUTS          // funcion de impresion de cadenas
%token PRINTF        // funcion de impresion formateada
%token RETURN        // sentencia return
%token SWITCH        // estructura switch
%token CASE          // etiqueta case
%token DEFAULT       // etiqueta default
%token BREAK         // sentencia break
%token INC           // macro INC(x)
%token DEC           // macro DEC(x)
%token EQ            // operador ==
%token NE            // operador !=
%token LE            // operador <=
%token GE            // operador >=
%token AND           // operador &&
%token OR            // operador ||

%right '='
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'
%right '!' UNARY_SIGN

%%                            // Sección 3 Gramática - Semántico

// ----- Estructura del programa -----

programa:     decl_globales def_funciones fun_main    { ; }
            ;

decl_globales:
              /* empty */                    { $$.code = gen_code ("") ; }
            | decl_var_global decl_globales  { $$ = $2 ; }
            ;

decl_var_global:
              INTEGER lista_vars_global ';'  { printf ("%s\n", $2.code) ;
                                               $$.code = gen_code ("") ; }
            ;

lista_vars_global:
              item_var_global                       { $$ = $1 ; }
            | item_var_global ',' lista_vars_global { sprintf (temp, "%s\n%s", $1.code, $3.code) ;
                                                      $$.code = gen_code (temp) ; }
            ;

item_var_global:
              IDENTIF                        { sprintf (temp, "(setq %s 0)", $1.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '=' NUMBER             { sprintf (temp, "(setq %s %d)", $1.code, $3.value) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '[' NUMBER ']'         { sprintf (temp, "(setq %s (make-array %d))", $1.code, $3.value) ;
                                               $$.code = gen_code (temp) ; }
            ;

def_funciones:
              /* empty */                    { $$.code = gen_code ("") ; }
            | def_fun def_funciones          { $$ = $2 ; }
            ;

def_fun:
              IDENTIF '(' params_def ')' '{' { strcpy (current_fun, $1.code) ;
                                               local_table_reset () ; }
              decl_locales sentencias '}'
                                             { printf ("%s(defun %s (%s)\n%s)\n",
                                                       $7.code, $1.code, $3.code, $8.code) ;
                                               strcpy (current_fun, "") ;
                                               local_table_reset () ;
                                               $$.code = gen_code ("") ; }
            ;

// ----- Parámetros de definición -----

params_def:
              /* empty */                    { $$.code = gen_code ("") ; }
            | lista_params_def               { $$ = $1 ; }
            ;

lista_params_def:
              INTEGER IDENTIF               { $$.code = gen_code ($2.code) ; }
            | INTEGER IDENTIF ',' lista_params_def
                                             { sprintf (temp, "%s %s", $2.code, $4.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

fun_main: MAIN '(' ')' '{'  { strcpy (current_fun, "main") ;
                               local_table_reset () ; }
          decl_locales sentencias '}'
                                             { printf ("%s(defun main ()\n%s)\n", $6.code, $7.code) ;
                                               strcpy (current_fun, "") ;
                                               local_table_reset () ;
                                               $$.code = gen_code ("") ; }
            ;

decl_locales:
              /* empty */                    { $$.code = gen_code ("") ; }
            | decl_var_local decl_locales    { sprintf (temp, "%s%s", $1.code, $2.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

decl_var_local:
              INTEGER lista_vars_local ';'   { $$ = $2 ; }
            ;

lista_vars_local:
              item_var_local                       { $$ = $1 ; }
            | item_var_local ',' lista_vars_local  { sprintf (temp, "%s%s", $1.code, $3.code) ;
                                                     $$.code = gen_code (temp) ; }
            ;

item_var_local:
              IDENTIF                        { local_table_insert ($1.code) ;
                                               sprintf (temp, "(setq %s_%s 0)\n", current_fun, $1.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '=' NUMBER             { local_table_insert ($1.code) ;
                                               sprintf (temp, "(setq %s_%s %d)\n", current_fun, $1.code, $3.value) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '[' NUMBER ']'         { local_table_insert ($1.code) ;
                                               sprintf (temp, "(setq %s_%s (make-array %d))\n", current_fun, $1.code, $3.value) ;
                                               $$.code = gen_code (temp) ; }
            ;

// ----- Lista de sentencias -----

sentencias:
              /* empty */                    { $$.code = gen_code ("") ; }
            | sentencia ';' sentencias       { sprintf (temp, "  %s\n%s", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | bloque sentencias              { sprintf (temp, "  %s\n%s", $1.code, $2.code) ;
                                               $$.code = gen_code (temp) ; }
            ;


bloque:
              WHILE '(' expre ')' '{' sentencias '}'
                                             { sprintf (temp, "(loop while %s do\n%s  )",
                                               $3.code, $6.code) ;
                                               $$.code = gen_code (temp) ; }
            | IF '(' expre ')' '{' sentencias '}'
                                             { sprintf (temp, "(if %s\n    (progn\n%s    ))",
                                               $3.code, $6.code) ;
                                               $$.code = gen_code (temp) ; }
            | IF '(' expre ')' '{' sentencias '}' ELSE '{' sentencias '}'
                                             { sprintf (temp,
                                               "(if %s\n    (progn\n%s    )\n    (progn\n%s    ))",
                                               $3.code, $6.code, $10.code) ;
                                               $$.code = gen_code (temp) ; }
            | FOR '(' for_init ';' expre ';' inc_dec ')' '{' sentencias '}'
                                             { sprintf (temp,
                                               "(setf %s)\n  (loop while %s do\n%s    (setf %s)\n  )",
                                               $3.code, $5.code, $10.code, $7.code) ;
                                               $$.code = gen_code (temp) ; }
            | SWITCH '(' expre ')' '{' casos '}'
                                             { sprintf (temp, "(case %s\n%s)", $3.code, $6.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

for_init:
              IDENTIF '=' expre              { char *vn = resolve_var ($1.code) ;
                                               sprintf (temp, "%s %s", vn, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

inc_dec:
              INC '(' IDENTIF ')'            { char *vn = resolve_var ($3.code) ;
                                               sprintf (temp, "%s (+ %s 1)", vn, vn) ;
                                               $$.code = gen_code (temp) ; }
            | DEC '(' IDENTIF ')'            { char *vn = resolve_var ($3.code) ;
                                               sprintf (temp, "%s (- %s 1)", vn, vn) ;
                                               $$.code = gen_code (temp) ; }
            ;

casos:
              /* empty */                    { $$.code = gen_code ("") ; }
            | caso casos                     { sprintf (temp, "%s%s", $1.code, $2.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

caso:
              CASE NUMBER ':' sentencias BREAK ';'
                                             { sprintf (temp, "  (%d %s)\n", $2.value, $4.code) ;
                                               $$.code = gen_code (temp) ; }
            | DEFAULT ':' sentencias
                                             { sprintf (temp, "  (otherwise %s)\n", $3.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

// ----- Asignación encadenada: a = b = c = expr -----
// (genera (setf a (setf b (setf c expr))) de forma recursiva a derechas)

asign_rhs:
              IDENTIF '=' asign_rhs          { char *vn = resolve_var ($1.code) ;
                                               sprintf (temp, "(setf %s %s)", vn, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre                          { $$ = $1 ; }
            ;

// ----- Sentencias simples -----

sentencia:
              IDENTIF '=' asign_rhs          { char *vn = resolve_var ($1.code) ;
                                               sprintf (temp, "(setf %s %s)", vn, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '[' expre ']' '=' expre
                                             { char *vn = resolve_var ($1.code) ;
                                               sprintf (temp, "(setf (aref %s %s) %s)", vn, $3.code, $6.code) ;
                                               $$.code = gen_code (temp) ; }
            | PUTS '(' STRING ')'            { sprintf (temp, "(print \"%s\")", $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | PRINTF '(' STRING ')'          { $$.code = gen_code ("") ; }
            | PRINTF '(' STRING ',' lista_printf ')'
                                             { $$ = $5 ; }
            | RETURN expre                   { sprintf (temp, "(return-from %s %s)", current_fun, $2.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '(' args_call ')'      { sprintf (temp, "(%s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | INC '(' IDENTIF ')'            { char *vn = resolve_var ($3.code) ;
                                               sprintf (temp, "(setf %s (+ %s 1))", vn, vn) ;
                                               $$.code = gen_code (temp) ; }
            | DEC '(' IDENTIF ')'            { char *vn = resolve_var ($3.code) ;
                                               sprintf (temp, "(setf %s (- %s 1))", vn, vn) ;
                                               $$.code = gen_code (temp) ; }
            ;

// ----- Argumentos de llamada a función -----

args_call:
              /* empty */                    { $$.code = gen_code ("") ; }
            | lista_args_call                { $$ = $1 ; }
            ;

lista_args_call:
              expre                          { $$ = $1 ; }
            | expre ',' lista_args_call      { sprintf (temp, "%s %s", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

lista_printf:
              elem_printf                    { $$ = $1 ; }
            | elem_printf ',' lista_printf   { sprintf (temp, "%s %s", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

elem_printf:  expre                          { sprintf (temp, "(princ %s)", $1.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

expre:
              term                           { $$ = $1 ; }
            | expre '+' expre        { sprintf (temp, "(+ %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '-' expre        { sprintf (temp, "(- %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '*' expre        { sprintf (temp, "(* %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '/' expre        { sprintf (temp, "(/ %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '%' expre        { sprintf (temp, "(mod %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre EQ  expre        { sprintf (temp, "(= %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre NE  expre        { sprintf (temp, "(/= %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '<' expre        { sprintf (temp, "(< %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre '>' expre        { sprintf (temp, "(> %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre LE  expre        { sprintf (temp, "(<= %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre GE  expre        { sprintf (temp, "(>= %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre AND expre        { sprintf (temp, "(and %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | expre OR  expre        { sprintf (temp, "(or %s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

term:
              operando                       { $$ = $1 ; }
            | '+' operando %prec UNARY_SIGN  { $$ = $2 ; }
            | '-' operando %prec UNARY_SIGN  { sprintf (temp, "(- %s)", $2.code) ;
                                               $$.code = gen_code (temp) ; }
            | '!' operando %prec UNARY_SIGN  { sprintf (temp, "(not %s)", $2.code) ;
                                               $$.code = gen_code (temp) ; }
            ;

operando:
              IDENTIF                        { $$.code = gen_code (resolve_var ($1.code)) ; }
            | NUMBER                         { sprintf (temp, "%d", $1.value) ;
                                               $$.code = gen_code (temp) ; }
            | STRING                         { sprintf (temp, "\"%s\"", $1.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '[' expre ']'          { char *vn = resolve_var ($1.code) ;
                                               sprintf (temp, "(aref %s %s)", vn, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | IDENTIF '(' args_call ')'      { sprintf (temp, "(%s %s)", $1.code, $3.code) ;
                                               $$.code = gen_code (temp) ; }
            | '(' expre ')'                  { $$ = $2 ; }
            ;


%%                            // SECCIÓN 4    Codigo en C

int n_line = 1 ;

int yyerror (mensaje)
char *mensaje ;
{
    fprintf (stderr, "%s en la línea %d\n", mensaje, n_line) ;
    printf ( "\n") ;	// bye
}

char *int_to_string (int n)
{
    char ltemp [2048] ;

    sprintf (ltemp, "%d", n) ;

    return gen_code (ltemp) ;
}

char *char_to_string (char c)
{
    char ltemp [2048] ;

    sprintf (ltemp, "%c", c) ;

    return gen_code (ltemp) ;
}

char *my_malloc (int nbytes)       // reserva n bytes de memoria dinamica
{
    char *p ;
    static long int nb = 0;        // sirven para contabilizar la memoria
    static int nv = 0 ;            // solicitada en total

    p = malloc (nbytes) ;
    if (p == NULL) {
        fprintf (stderr, "No queda memoria para %d bytes mas\n", nbytes) ;
        fprintf (stderr, "Reservados %ld bytes en %d llamadas\n", nb, nv) ;
        exit (0) ;
    }
    nb += (long) nbytes ;
    nv++ ;

    return p ;
}


/********************** Sección de palabras reservadas *********************/

typedef struct s_keyword { // para las palabras reservadas de C
    char *name ;
    int token ;
} t_keyword ;

t_keyword keywords [] = { // define las palabras reservadas y los
    "main",        MAIN,           // y los token asociados
    "int",         INTEGER,
    "while",       WHILE,
    "for",         FOR,
    "if",          IF,
    "else",        ELSE,
    "puts",        PUTS,
    "printf",      PRINTF,
    "return",      RETURN,
    "switch",      SWITCH,
    "case",        CASE,
    "default",     DEFAULT,
    "break",       BREAK,
    "inc",         INC,
    "dec",         DEC,
    "==",          EQ,
    "!=",          NE,
    "<=",          LE,
    ">=",          GE,
    "&&",          AND,
    "||",          OR,
    NULL,          0               // para marcar el fin de la tabla
} ;

t_keyword *search_keyword (char *symbol_name)
{                                  // Busca n_s en la tabla de pal. res.
                                   // y devuelve puntero a registro (simbolo)
    int i ;
    t_keyword *sim ;

    i = 0 ;
    sim = keywords ;
    while (sim [i].name != NULL) {
	    if (strcmp (sim [i].name, symbol_name) == 0) {
		                             // strcmp(a, b) devuelve == 0 si a==b
            return &(sim [i]) ;
        }
        i++ ;
    }

    return NULL ;
}

 
/******************* Sección del analizador lexicografico ******************/

char *gen_code (char *name)     // copia el argumento a un
{                                      // string en memoria dinámica
    char *p ;
    int l ;
	
    l = strlen (name)+1 ;
    p = (char *) my_malloc (l) ;
    strcpy (p, name) ;
	
    return p ;
}


int yylex ()
{
// NO MODIFICAR ESTA FUNCIÓN SIN PERMISO
    int i ;
    unsigned char c ;
    unsigned char cc ;
    char ops_expandibles [] = "!<=|>%&/+-*" ;
    char temp_str [256] ;
    t_keyword *symbol ;

    do {
        c = getchar () ;

        if (c == '#') {	// Ignora las líneas que empiezan por #  (#define, #include)
            do {		//	OJO que puede funcionar mal si una linea contiene #
                c = getchar () ;
            } while (c != '\n') ;
        }

        if (c == '/') {	// Si la línea contiene un / puede ser inicio de comentario
            cc = getchar () ;
            if (cc != '/') {   // Si el siguiente char es /  es un comentario, pero...
                ungetc (cc, stdin) ;
            } else {
                c = getchar () ;	// ...
                if (c == '@') {	// Si es la secuencia //@  ==> transcribimos la linea
                    do {		// Se trata de código inline (Codigo embebido en C)
                        c = getchar () ;
                        putchar (c) ;
                    } while (c != '\n') ;
                } else {		// ==> comentario, ignorar la línea
                    while (c != '\n') {
                        c = getchar () ;
                    }
                }
            }
        } else if (c == '\\') c = getchar () ;
		
        if (c == '\n')
            n_line++ ;

    } while (c == ' ' || c == '\n' || c == 10 || c == 13 || c == '\t') ;

    if (c == '\"') {
        i = 0 ;
        do {
            c = getchar () ;
            temp_str [i++] = c ;
        } while (c != '\"' && i < 255) ;
        if (i == 256) {
            printf ("AVISO: string con mas de 255 caracteres en línea %d\n", n_line) ;
        }		 	
        temp_str [--i] = '\0' ;
        yylval.code = gen_code (temp_str) ;
        return (STRING) ;
    }

    if (c == '.' || (c >= '0' && c <= '9')) {
        ungetc (c, stdin) ;
        scanf ("%d", &yylval.value) ;
        return NUMBER ;
    }

    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
        i = 0 ;
        while (((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '_') && i < 255) {
            temp_str [i++] = tolower (c) ;
            c = getchar () ;
        }
        temp_str [i] = '\0' ;
        ungetc (c, stdin) ;

        yylval.code = gen_code (temp_str) ;
        symbol = search_keyword (yylval.code) ;
        if (symbol == NULL) {    // no es palabra reservada -> identificador
            return (IDENTIF) ;
        } else {
            return (symbol->token) ;
        }
    }

    if (strchr (ops_expandibles, c) != NULL) { // busca c en ops_expandibles
        cc = getchar () ;
        sprintf (temp_str, "%c%c", (char) c, (char) cc) ;
        symbol = search_keyword (temp_str) ;
        if (symbol == NULL) {
            ungetc (cc, stdin) ;
            yylval.code = NULL ;
            return (c) ;
        } else {
            yylval.code = gen_code (temp_str) ; // aunque no se use
            return (symbol->token) ;
        }
    }

    if (c == EOF || c == 255 || c == 26) {
        return (0) ;
    }

    return c ;
}


int main ()
{
    yyparse () ;
}
