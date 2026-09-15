// test.mc - Programa de teste para o scanner de Micro C
//
// PARTE 1: o programa de exemplo original fornecido pelo professor (um
// programa Micro C valido), mantido sem alteracoes.
//
// PARTE 2: secoes adicionais que exercitam todos os tokens da linguagem
// e todos os erros lexicos que podem ser testados dentro de um arquivo de
// texto comum. Cada secao comeca com um comentario dizendo o que se
// espera. Todos os erros desta parte sao recuperaveis: a leitura continua
// normalmente depois de cada um.
//
// Casos que NAO cabem neste arquivo (estao em arquivos separados):
//   teste_eof_string.mc        -> EOF dentro de string
//   teste_eof_string_barra.mc  -> EOF logo apos uma barra invertida na string
//   teste_eof_comentario.mc    -> EOF dentro de comentario de bloco
//   teste_string_nulo.mc       -> byte nulo literal dentro de string
// (o EOF so acontece uma vez, no fim do arquivo, e um byte nulo nao se
// digita num editor de texto)

// ======================================================================
// PARTE 1 - programa original
// ======================================================================

/* Calcula o fatorial de um numero inteiro utilizando um laco for. */
int fatorial(int n) {
    int resultado;
    int i;

    resultado = 1;
    for (i = 1; i <= n; i = i + 1) {
        resultado = resultado * i;
    }
    return resultado;
}

int main() {
    int x;
    int y;
    char c;
    char letras[10];

    x = 5;
    y = fatorial(x);

    if (y > 100) {
        print("Resultado grande");
    } else {
        print("Resultado pequeno");
    }

    c = 'A';
    letras[0] = 'H';
    letras[1] = 'i';

    // Testando operadores relacionais e logicos
    if (x >= 0 && y != 0) {
        print("x e nao-negativo e y e diferente de zero");
    }

    if (x == 5 || y == 0) {
        print("condicao ou satisfeita");
    }

    if (!(x < 0)) {
        print("x nao e negativo");
    }

    return 0;
}

// ======================================================================
// PARTE 2 - testes adicionais
// ======================================================================

// ----- SECAO 1: palavras reservadas e identificadores -----------------
// Espera-se: MAIN IF ELSE FOR RETURN INT CHAR PRINT
main if else for return int char print
// Espera-se: 8 ID (diferencia maiusculas; palavra reservada so se for inteira)
iff Int MAIN _if main_ print2 printf x1
// Espera-se: ID '_'  ID '__a__'  ID com lexema longo
_ __a__ um_identificador_bem_comprido_para_testar_lexemas_longos_0123456789

// ----- SECAO 2: constantes inteiras -----------------------------------
// Espera-se: INTEGERCONST '0' '42' '007' '123456789012345678901234567890'
0 42 007 123456789012345678901234567890
// Espera-se: INTEGERCONST '123' e ID 'abc' (nao e erro lexico)
123abc

// ----- SECAO 3: inteiros negativos x operador de subtracao ------------
// Regra: um "-" colado em digitos faz parte do numero, EXCETO quando o
// token anterior termina um operando (ID, INTEGERCONST, CHARCONST,
// STRINGCONST, RPAREN ou RBRACKET); nesse caso e MINUS.
// Espera-se: ID ASSIGN INTEGERCONST '-1' SEMICOLON
x = -1;
// Espera-se: ID LPAREN INTEGERCONST '-2' COMMA INTEGERCONST '-3' RPAREN SEMICOLON
f(-2, -3);
// Espera-se: ID LBRACKET INTEGERCONST '-4' RBRACKET SEMICOLON
v[-4];
// Espera-se: RETURN INTEGERCONST '-5' SEMICOLON
return -5;
// Espera-se: ID ASSIGN ID MUL INTEGERCONST '-6' SEMICOLON
x = y*-6;
// Espera-se: LBRACE INTEGERCONST '-7' SEMICOLON RBRACE
{ -7; }
// Espera-se: ID SEMICOLON INTEGERCONST '-8' SEMICOLON
x; -8;
// Espera-se (tres linhas): ID MINUS INTEGERCONST '1' SEMICOLON
x-1;
x -1;
x - 1;
// Espera-se: ID MINUS INTEGERCONST '-1' SEMICOLON
x - -1;
// Espera-se: MINUS INTEGERCONST '-1' SEMICOLON
--1;
// Espera-se: INTEGERCONST '2' MINUS INTEGERCONST '3' SEMICOLON
2-3;
// Espera-se: ID LBRACKET INTEGERCONST '0' RBRACKET MINUS INTEGERCONST '1' SEMICOLON
v[0]-1;
// Espera-se: LPAREN ID RPAREN MINUS INTEGERCONST '1' SEMICOLON
(a)-1;
// Espera-se: CHARCONST 'a' MINUS INTEGERCONST '1' SEMICOLON
'a'-1;
// Espera-se: STRINGCONST 's' MINUS INTEGERCONST '1' SEMICOLON
"s"-1;
// O que decide e o token anterior, mesmo que esteja na linha de cima.
// Espera-se: ID 'y' e, na linha seguinte, MINUS INTEGERCONST '1' SEMICOLON
y
-1;

// ----- SECAO 4: operadores relacionais e logicos ----------------------
// Espera-se: ID LEQ ID LT ID GEQ ID GT ID EQ ID NEQ ID NOT ID AND ID OR ID
a<=b<c>=d>e==f!=g!h&&i||j
// Espera-se: a mesma sequencia, agora separada por espacos
a <= b < c >= d > e == f != g ! h && i || j
// Espera-se: EQ ASSIGN  NEQ ASSIGN  LT LT  GT GT  NOT NOT  ASSIGN LT
=== !== << >> !! =<
// Espera-se: AND e ERRO '&'
&&&
// Espera-se: OR e ERRO '|'
|||
// Espera-se: ERRO '&' e ERRO '|' (sozinhos nao sao operadores de Micro C)
& |

// ----- SECAO 5: operadores aritmeticos e pontuacao --------------------
// Espera-se: PLUS MINUS MUL DIV MOD SEMICOLON COMMA LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET
+ - * / % ; , ( ) { } [ ]
// Espera-se: ID PLUS ID MINUS ID MUL ID DIV ID MOD ID
a+b-c*d/e%f

// ----- SECAO 6: comentarios -------------------------------------------
// Nenhum destes comentarios gera token: // */ "texto" 'c' /*
/* comentario de bloco numa unica linha */
/*
   comentario de bloco com
   varias linhas (as linhas continuam sendo contadas)
*/
/**/
/***/
/* ** * / "aspas" 'apostrofo' // dentro do bloco */
// Espera-se: ID 'antes' e ID 'depois'
antes /* meio */ depois
// Espera-se: ID 'a', ERRO Comentario nao iniciado, ID 'b'
a*/b
// Espera-se: ERRO Comentario nao iniciado (fechamento sobrando)
/* fecha uma vez */ */

// ----- SECAO 7: constantes de caractere -------------------------------
// Espera-se: CHARCONST 'A' 'z' '0' ' ' '"' ';'
'A' 'z' '0' ' ' '"' ';'
// Espera-se: 7 CHARCONST com escapes convertidos: nova linha, tabulacao,
// byte nulo, barra invertida, apostrofo, aspas e 'q' (escape desconhecido).
// Na saida, a nova linha convertida quebra a linha e o byte nulo nao aparece.
'\n' '\t' '\0' '\\' '\'' '\"' '\q'
// Espera-se: ERRO Constante de caractere invalida (vazia)
''
// Espera-se: ERRO Constante de caractere invalida (mais de um caractere)
'ab'
// Espera-se: ID 'c', ASSIGN, ERRO Constante de caractere nao terminada
c = 'x;
// Espera-se: ERRO Constante de caractere nao terminada (apostrofo sozinho)
'

// ----- SECAO 8: constantes de string ----------------------------------
// Espera-se: STRINGCONST vazia (lexema = '')
""
// Espera-se: STRINGCONST 'texto simples com espacos'
"texto simples com espacos"
// Espera-se: STRINGCONST com escapes convertidos (tabulacao, aspas, barra
// e nova linha no final, que quebra a linha da saida)
"tab:\t|aspas:\"|barra:\\|fim\n"
// Espera-se: STRINGCONST de 5 bytes: a, b, byte nulo (escape valido), c, d
"ab\0cd"
// Espera-se: STRINGCONST com valor q' (\q vira q; apostrofo e comum na string)
"\q'"
// Espera-se: STRINGCONST com o texto abaixo (nao sao comentarios)
"/* nao e comentario */ // nem isto"
// Espera-se: uma unica STRINGCONST de duas linhas (quebra de linha escapada),
// reportada na linha em que a string TERMINA
"primeira linha\
segunda linha"
// Espera-se: PRINT LPAREN STRINGCONST 'ola, mundo' RPAREN SEMICOLON
print("ola, mundo");
// Espera-se: PRINT LPAREN e ERRO String nao terminada (nesta linha)
print("sem fechar);
// Espera-se: ID 'recuperou' SEMICOLON, na linha seguinte ao erro
recuperou;

// ----- SECAO 9: caracteres invalidos ----------------------------------
// Espera-se: um ERRO para cada caractere: @ # $ ? : . ~ ` \
@ # $ ? : . ~ ` \
// Espera-se: ID 'a', ERRO '@', ID 'b' (a leitura continua no caractere seguinte)
a@b

// fim do arquivo de teste
