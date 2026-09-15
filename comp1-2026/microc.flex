/*
 * microc.flex
 *
 * Analisador lexico (scanner) para a linguagem Micro C.
 * Disciplina: Compiladores I - FACOM
 * Trabalho Pratico 1 - Analise Lexica
 *
 * Este arquivo foi construido a partir do esqueleto fornecido pelo
 * professor. Todos os trechos que o esqueleto deixava para o aluno
 * completar foram implementados, e cada decisao de projeto esta
 * explicada nos comentarios ao longo do arquivo.
 *
 * Organizacao (as 4 partes de um arquivo flex):
 *   Declaracoes (entre %{ e %}) : tokens, tabela de strings, buffer de
 *                                 strings e funcoes auxiliares em C.
 *   Definicoes                   : nomes de expressoes regulares, opcoes
 *                                 do flex e estados (start conditions).
 *   Regras                       : expressao regular + acao em C.
 *   Sub-rotinas do usuario       : yywrap() e o main() de teste.
 *
 * Compilacao:
 *      flex microc.flex
 *      gcc lex.yy.c -o lexer
 *
 * Uso:
 *      ./lexer test.mc
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

/* ---------------------------------------------------------------------
 * 1. VOCABULARIO DE TOKENS (equivalente a tokens.h)
 *
 * IMPORTANTE: os tokens de um unico caractere (";", ",", "(" ...) usam
 * os valores deste enum, e NAO o codigo ASCII do caractere. O main() de
 * teste usa o valor do token como indice do vetor nome_token[]; um
 * codigo ASCII (ex.: 59 para ';') leria fora do vetor.
 * ------------------------------------------------------------------- */

typedef enum {
    /* Tokens fundamentais */
    UNDEF,          /* token indefinido (usado para reportar erros) */
    ID,             /* identificador                                */
    END_OF_FILE,    /* fim de arquivo                                */

    /* Constantes literais */
    INTEGERCONST,
    CHARCONST,
    STRINGCONST,

    /* Operadores aritmeticos */
    PLUS, MINUS, MUL, DIV, MOD,

    /* Operadores relacionais e logicos */
    EQ, NEQ, LT, GT, LEQ, GEQ, AND, OR, NOT,

    /* Simbolos de atribuicao e pontuacao */
    ASSIGN, SEMICOLON, COMMA, LPAREN, RPAREN,
    LBRACE, RBRACE, LBRACKET, RBRACKET,

    /* Palavras reservadas */
    MAIN, IF, ELSE, FOR, RETURN, INT, CHAR, PRINT
} TokenType;

/* Nomes dos tokens, usados apenas pelo main() de teste abaixo para
 * imprimir o tipo de cada token de forma legivel. Mantenha esta lista
 * na MESMA ORDEM do enum TokenType. */
static const char *nome_token[] = {
    "UNDEF", "ID", "END_OF_FILE",
    "INTEGERCONST", "CHARCONST", "STRINGCONST",
    "PLUS", "MINUS", "MUL", "DIV", "MOD",
    "EQ", "NEQ", "LT", "GT", "LEQ", "GEQ", "AND", "OR", "NOT",
    "ASSIGN", "SEMICOLON", "COMMA", "LPAREN", "RPAREN",
    "LBRACE", "RBRACE", "LBRACKET", "RBRACKET",
    "MAIN", "IF", "ELSE", "FOR", "RETURN", "INT", "CHAR", "PRINT"
};

/* ---------------------------------------------------------------------
 * 2. MENSAGENS DE ERRO LEXICO
 *
 * Textos exatos exigidos pelo enunciado (Secao 4.1). As duas mensagens
 * de constante de caractere foram definidas por nos, pois o enunciado
 * pede o tratamento desse erro mas nao fixa o texto.
 * ------------------------------------------------------------------- */

#define MSG_EOF_COMENTARIO      "EOF em comentario"
#define MSG_COMENTARIO_NAO_INIC "Comentario nao iniciado"
#define MSG_STRING_NAO_TERM     "String nao terminada"
#define MSG_STRING_NULO         "String contem caractere nulo"
#define MSG_EOF_STRING          "EOF em string"
#define MSG_CHAR_NAO_TERM       "Constante de caractere nao terminada"
#define MSG_CHAR_INVALIDA       "Constante de caractere invalida"

/* ---------------------------------------------------------------------
 * 3. ALOCACAO DE MEMORIA COM ENCERRAMENTO CONTROLADO
 *
 * O enunciado exige encerramento controlado em caso de erro fatal (sem
 * core dump). Toda alocacao passa por estas funcoes: se malloc/realloc
 * falhar, uma mensagem vai para stderr e o programa termina com exit(1).
 * Esta e a UNICA situacao em que o scanner imprime algo diretamente; os
 * erros lexicos comuns sao devolvidos como token UNDEF.
 * ------------------------------------------------------------------- */

static void erro_fatal(const char *mensagem) {
    fprintf(stderr, "ERRO FATAL: %s\n", mensagem);
    exit(1);
}

static void *aloca_memoria(size_t bytes) {
    void *memoria = malloc(bytes);
    if (memoria == NULL) {
        erro_fatal("memoria insuficiente");
    }
    return memoria;
}

static void *realoca_memoria(void *memoria_antiga, size_t bytes) {
    void *memoria = realloc(memoria_antiga, bytes);
    if (memoria == NULL) {
        erro_fatal("memoria insuficiente");
    }
    return memoria;
}

/* ---------------------------------------------------------------------
 * 4. TABELA DE STRINGS (Secoes 4.2 e 5 do enunciado)
 *
 * Um programa repete muito os mesmos lexemas (o mesmo identificador, a
 * mesma constante). Em vez de guardar uma copia nova a cada ocorrencia,
 * cada lexema DISTINTO e guardado uma unica vez numa tabela, e o scanner
 * devolve sempre o mesmo ponteiro (Symbol *) para ele. Isso economiza
 * memoria e permite comparar lexemas comparando so ponteiros.
 *
 * Estrutura escolhida: TABELA HASH COM ENCADEAMENTO SEPARADO.
 *   - A tabela e um vetor de NUM_BALDES ponteiros ("baldes").
 *   - A funcao hash transforma os bytes do lexema num numero entre 0 e
 *     NUM_BALDES-1, que diz em qual balde o lexema deve ficar.
 *   - Lexemas diferentes podem cair no mesmo balde (colisao). Por isso
 *     cada balde e uma LISTA ENCADEADA de Symbol (campo "proximo").
 *   - Busca e insercao: calcula o hash e percorre so a lista daquele
 *     balde. Com um hash que espalha bem, as listas ficam curtas e o
 *     custo medio e O(1). O pior caso (tudo no mesmo balde) seria O(n).
 *
 * Por que guardar "tamanho" em vez de usar strlen()?
 *   Uma string de Micro C pode conter o escape \0, que vira um byte nulo
 *   DENTRO do valor (ex.: "ab\0cd" tem 5 bytes). strlen, strcmp e strcpy
 *   param no primeiro byte nulo e perderiam o resto. Por isso o hash e a
 *   comparacao usam o tamanho explicito e memcmp.
 *
 * Usamos tres tabelas (mesma estrutura, instancias diferentes), no mesmo
 * espirito dos exemplos idtable/inttable/stringtable do livro-texto:
 *   tabela_ids      -> lexemas de ID
 *   tabela_inteiros -> texto das constantes INTEGERCONST (ex.: "-42")
 *   tabela_strings  -> valores ja convertidos de STRINGCONST e CHARCONST
 * ------------------------------------------------------------------- */

typedef struct Symbol {
    char *texto;             /* copia dos bytes do lexema, com um '\0' extra no final */
    int tamanho;             /* quantidade de bytes validos (pode haver '\0' no meio) */
    struct Symbol *proximo;  /* proximo simbolo no mesmo balde (encadeamento) */
} Symbol;

/* 211 e primo; um numero primo de baldes ajuda a espalhar os valores. */
#define NUM_BALDES 211

typedef struct {
    Symbol *baldes[NUM_BALDES];  /* cada posicao e o inicio de uma lista */
} TabelaStrings;

/* Variaveis globais "static" comecam zeradas: todos os baldes = NULL. */
static TabelaStrings tabela_ids;
static TabelaStrings tabela_inteiros;
static TabelaStrings tabela_strings;

/* Funcao hash djb2 (Daniel J. Bernstein): hash = hash * 33 + byte.
 * Percorre exatamente "tamanho" bytes (nunca usa strlen). O calculo com
 * unsigned long pode "dar a volta" (overflow), o que em C e bem definido
 * para tipos sem sinal e nao prejudica o espalhamento. */
static unsigned long calcula_hash(const char *texto, int tamanho) {
    unsigned long hash = 5381;
    int i;
    for (i = 0; i < tamanho; i++) {
        hash = hash * 33 + (unsigned char) texto[i];
    }
    return hash % NUM_BALDES;
}

/* Procura o lexema (texto, tamanho) na tabela. Se ja existir, devolve o
 * Symbol existente, sem duplicar. Senao, cria uma copia, insere no
 * inicio da lista do balde e devolve o novo Symbol. */
static Symbol *tabela_adiciona(TabelaStrings *tabela, const char *texto, int tamanho) {
    unsigned long balde = calcula_hash(texto, tamanho);
    Symbol *atual;
    Symbol *novo;

    for (atual = tabela->baldes[balde]; atual != NULL; atual = atual->proximo) {
        /* Mesmo tamanho E mesmos bytes => e o mesmo lexema. O teste
         * tamanho == 0 evita chamar memcmp sem nada para comparar. */
        if (atual->tamanho == tamanho &&
            (tamanho == 0 || memcmp(atual->texto, texto, (size_t) tamanho) == 0)) {
            return atual;
        }
    }

    novo = aloca_memoria(sizeof(Symbol));
    novo->texto = aloca_memoria((size_t) tamanho + 1);
    if (tamanho > 0) {
        memcpy(novo->texto, texto, (size_t) tamanho);
    }
    novo->texto[tamanho] = '\0';  /* extra: nao faz parte do valor, so ajuda na depuracao */
    novo->tamanho = tamanho;
    novo->proximo = tabela->baldes[balde];
    tabela->baldes[balde] = novo;
    return novo;
}

/* Libera todos os simbolos de uma tabela (usada no fim do programa). */
static void tabela_libera(TabelaStrings *tabela) {
    int i;
    for (i = 0; i < NUM_BALDES; i++) {
        Symbol *atual = tabela->baldes[i];
        while (atual != NULL) {
            Symbol *proximo = atual->proximo;
            free(atual->texto);
            free(atual);
            atual = proximo;
        }
        tabela->baldes[i] = NULL;
    }
}

/* Valor semantico do token corrente.
 *   symbol    -> entrada na tabela de strings; preenchido para ID,
 *                INTEGERCONST, CHARCONST e STRINGCONST.
 *   error_msg -> mensagem de erro (string comum, nao e Symbol); usada
 *                apenas quando o token devolvido e UNDEF.
 * No esqueleto "symbol" era char*. Passou a ser Symbol* porque a Secao 5
 * do enunciado pede que o lexema seja uma entrada da tabela de strings. */
typedef struct {
    Symbol *symbol;
    char *error_msg;
} YYSTYPE;

YYSTYPE microc_yylval;

/* Linha atual do arquivo-fonte sendo processado. E incrementada toda vez
 * que uma quebra de linha e consumida pelo scanner: em codigo normal,
 * dentro de comentarios de bloco e em quebras de linha escapadas dentro
 * de strings. Cada quebra de linha e contada exatamente uma vez. */
int linha_atual = 1;

/* ---------------------------------------------------------------------
 * 5. ULTIMO TOKEN DEVOLVIDO (constantes inteiras negativas)
 *
 * O texto "-5" pode ser uma constante negativa (em "x = -5") ou o
 * operador de subtracao seguido de 5 (em "x-5"). Olhando so o texto nao
 * da para decidir: e preciso saber o que veio ANTES.
 *   - Se o token anterior TERMINA UM OPERANDO (identificador, constante,
 *     ")" ou "]"), o "-" so pode ser subtracao.
 *   - Caso contrario (inicio do arquivo, depois de "=", "(", ",", ";",
 *     "return", de outro operador...), o "-" faz parte do numero.
 *
 * Para isso guardamos o ultimo token devolvido. TODA regra que devolve
 * um token usa a macro RETORNA, que atualiza ultimo_token antes do
 * return (inclusive UNDEF e END_OF_FILE). Espacos, quebras de linha e
 * comentarios nao devolvem token, entao nao alteram ultimo_token.
 * ------------------------------------------------------------------- */

static TokenType ultimo_token = UNDEF;  /* UNDEF nao termina operando */

#define RETORNA(token) do { ultimo_token = (token); return (token); } while (0)

static int termina_operando(TokenType token) {
    switch (token) {
        case ID:
        case INTEGERCONST:
        case CHARCONST:
        case STRINGCONST:
        case RPAREN:
        case RBRACKET:
            return 1;
        default:
            return 0;
    }
}

/* ---------------------------------------------------------------------
 * 6. PALAVRAS RESERVADAS
 *
 * A regra de identificador casa qualquer palavra; depois comparamos o
 * lexema com cada palavra reservada usando strcmp (como sugerido no
 * esqueleto). Como a regra de identificador sempre pega a palavra
 * INTEIRA (casamento mais longo), "iff" e comparado inteiro e vira ID,
 * e nao IF seguido de "f". A comparacao diferencia maiusculas de
 * minusculas: "If" e "INT" sao identificadores.
 * ------------------------------------------------------------------- */

typedef struct {
    const char *palavra;
    TokenType token;
} PalavraReservada;

static const PalavraReservada palavras_reservadas[] = {
    { "main",   MAIN   },
    { "if",     IF     },
    { "else",   ELSE   },
    { "for",    FOR    },
    { "return", RETURN },
    { "int",    INT    },
    { "char",   CHAR   },
    { "print",  PRINT  }
};

#define NUM_PALAVRAS_RESERVADAS (sizeof(palavras_reservadas) / sizeof(palavras_reservadas[0]))

/* Devolve o token da palavra reservada, ou ID se nao for reservada. */
static TokenType busca_palavra_reservada(const char *lexema) {
    size_t i;
    for (i = 0; i < NUM_PALAVRAS_RESERVADAS; i++) {
        if (strcmp(lexema, palavras_reservadas[i].palavra) == 0) {
            return palavras_reservadas[i].token;
        }
    }
    return ID;
}

/* ---------------------------------------------------------------------
 * 7. SEQUENCIAS DE ESCAPE E BUFFER DE STRINGS
 * ------------------------------------------------------------------- */

/* Converte o caractere que vem depois de uma barra invertida:
 *   n -> nova linha,  t -> tabulacao,  0 -> byte nulo.
 * Qualquer outro caractere representa ele mesmo. Assim, barra+barra vira
 * uma barra, barra+aspas vira aspas, barra+apostrofo vira apostrofo, e um
 * escape desconhecido como barra+q vira simplesmente q (o enunciado nao
 * define erro para escape desconhecido). */
static char converte_escape(char caractere) {
    switch (caractere) {
        case 'n': return '\n';
        case 't': return '\t';
        case '0': return '\0';
        default:  return caractere;
    }
}

/* Uma string e lida em varios pedacos (texto comum, escapes, quebras de
 * linha escapadas). Os bytes ja convertidos vao sendo acumulados neste
 * buffer dinamico, que cresce com realloc: nao ha limite fixo de tamanho
 * e, portanto, nao ha risco de estouro de buffer. */
static char *string_buffer = NULL;    /* bytes ja convertidos da string atual */
static size_t string_capacidade = 0;  /* quantos bytes estao alocados        */
static int string_tamanho = 0;        /* quantos bytes estao em uso          */
static int string_tem_nulo = 0;       /* 1 se apareceu um byte nulo literal  */

/* Chamada ao encontrar a aspa de abertura: esvazia o buffer. */
static void string_inicia(void) {
    if (string_buffer == NULL) {
        string_capacidade = 64;
        string_buffer = aloca_memoria(string_capacidade);
    }
    string_tamanho = 0;
    string_tem_nulo = 0;
}

/* Acrescenta "quantidade" bytes ao final do buffer, dobrando a capacidade
 * quando necessario. Se a string ja tem um byte nulo literal, ela sera
 * descartada de qualquer forma, entao nada e guardado. */
static void string_acrescenta(const char *bytes, int quantidade) {
    size_t necessario;

    if (string_tem_nulo) {
        return;
    }
    if (quantidade > INT_MAX - string_tamanho) {
        erro_fatal("constante de string grande demais");
    }
    necessario = (size_t) string_tamanho + (size_t) quantidade;
    if (necessario > string_capacidade) {
        while (string_capacidade < necessario) {
            string_capacidade *= 2;
        }
        string_buffer = realoca_memoria(string_buffer, string_capacidade);
    }
    memcpy(string_buffer + string_tamanho, bytes, (size_t) quantidade);
    string_tamanho += quantidade;
}

/* Guarda o caractere invalido como uma string de 1 caractere, que e o
 * lexema de erro exigido pelo enunciado. Um buffer estatico evita alocar
 * memoria a cada erro; o main() imprime a mensagem logo em seguida. */
static char caractere_invalido[2];

/* Libera toda a memoria usada pelo scanner (chamada no fim do main). */
static void libera_memoria_scanner(void) {
    tabela_libera(&tabela_ids);
    tabela_libera(&tabela_inteiros);
    tabela_libera(&tabela_strings);
    free(string_buffer);
    string_buffer = NULL;
    string_capacidade = 0;
    string_tamanho = 0;
}

%}

/* -----------------------------------------------------------------------
 * SECAO DE DEFINICOES
 * ------------------------------------------------------------------- */

DIGIT       [0-9]
LETRA       [a-zA-Z_]
ALFANUM     [a-zA-Z0-9_]

/* noinput / nounput: nao usamos input() nem unput(); sem estas opcoes o
 *   gcc -Wall avisa que essas funcoes geradas pelo flex nao sao usadas.
 *   (yyless, que usamos, e uma macro e nao depende de unput.)
 * nodefault: remove a regra padrao do flex (que copiaria para a saida o
 *   texto nao reconhecido). Com ela, o proprio flex AVISA na geracao se
 *   existir alguma entrada que nao casa com nenhuma regra, o que prova
 *   que a especificacao lexica esta completa em todos os estados.
 * 8bit: o scanner aceita qualquer byte de 0 a 255 (ex.: bytes de UTF-8).
 * Nao usamos "noyywrap" porque a funcao yywrap() ja esta definida abaixo. */
%option noinput
%option nounput
%option nodefault
%option 8bit

/* Estados (start conditions) EXCLUSIVOS (%x): enquanto o scanner esta
 * num deles, so valem as regras marcadas com o nome do estado; as regras
 * normais (estado INITIAL) ficam desligadas.
 *   COMMENT   -> dentro de um comentario de bloco
 *   EM_STRING -> dentro de uma constante de string
 * Os nomes nao podem coincidir com nomes de tokens (CHAR, INT...): o flex
 * transforma cada estado num #define, que trocaria o valor do token. */
%x COMMENT
%x EM_STRING

%%

 /* =======================================================================
  * SECAO DE REGRAS
  *
  * Como o flex escolhe a regra (vale para o arquivo inteiro):
  *   1) Casamento mais longo: vence a regra que casa MAIS caracteres a
  *      partir da posicao atual (ex.: "<=" vence "<").
  *   2) Empate de tamanho: vence a regra que aparece PRIMEIRO no arquivo.
  *   3) Regras sem estado valem so no estado INITIAL; regras com <COMMENT>
  *      ou <EM_STRING> valem so dentro desses estados.
  * ===================================================================== */

 /* --- Fim de arquivo -----------------------------------------------------
  * Tratado explicitamente (em vez de depender do retorno automatico 0 do
  * flex), pois o token UNDEF tambem vale 0 no enum TokenType -- se
  * dependessemos do comportamento padrao, um erro lexico seria confundido
  * com o fim do arquivo pelo main() de teste.
  *
  * CORRECAO EM RELACAO AO ESQUELETO: a regra agora e <INITIAL><<EOF>>, e nao
  * apenas <<EOF>>. No flex, um <<EOF>> SEM estado vale para todos os estados
  * que ainda nao tem regra de EOF naquele ponto do arquivo, inclusive os
  * exclusivos. Como esta regra vem antes das regras de EOF de COMMENT e de
  * EM_STRING, ela "tomaria" o EOF desses estados, o flex avisaria
  * "multiple <<EOF>> rules" e ignoraria as regras de erro: um comentario ou
  * uma string sem fechamento terminaria o arquivo em silencio. Indicar o
  * estado INITIAL deixa cada estado com a sua propria regra de EOF. */
<INITIAL><<EOF>>    { RETORNA(END_OF_FILE); }

 /* --- Espacos em branco e quebras de linha ------------------------------
  * Espaco, tabulacao, \r (arquivos com fim de linha do Windows), \f e \v
  * sao ignorados, como em C. A quebra de linha so incrementa a linha. */
\n                  { linha_atual++; }
[ \t\r\f\v]+        { /* ignora espacos em branco */ }

 /* --- Comentarios ---------------------------------------------------------
  * Comentario de linha: ".*" nao casa a quebra de linha, entao ela fica
  * para a regra acima, que conta a linha.
  * Comentario de bloco: ao ver a abertura, entramos no estado COMMENT e
  * tudo e ignorado ate o fechamento. Nao ha aninhamento (como em C): o
  * primeiro fechamento encerra o comentario. */
"//".*              { /* comentario de linha: ignora ate o fim da linha */ }

"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); }
<COMMENT>\n         { linha_atual++; }
 /* EOF dentro de comentario. CORRECAO EM RELACAO AO ESQUELETO: e preciso
  * voltar ao estado INITIAL antes de retornar. Sem isso, a proxima chamada
  * de yylex() continuaria no estado COMMENT, encontraria o EOF de novo e
  * devolveria este mesmo erro para sempre (loop infinito). Com o
  * BEGIN(INITIAL), a proxima chamada cai no <<EOF>> normal e devolve
  * END_OF_FILE. */
<COMMENT><<EOF>>    {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = MSG_EOF_COMENTARIO;
                        RETORNA(UNDEF);
                    }
<COMMENT>.          { /* consome qualquer outro caractere dentro do comentario */ }

 /* Fechamento de comentario sem abertura correspondente. Pelo casamento
  * mais longo, estes 2 caracteres vencem a regra do "*" sozinho, entao
  * nao viram MUL seguido de DIV. */
"*/"                {
                        microc_yylval.error_msg = MSG_COMENTARIO_NAO_INIC;
                        RETORNA(UNDEF);
                    }

 /* --- Palavras reservadas e identificadores -------------------------------
  * Casa a palavra inteira e so entao decide se e reservada (ver secao 6 das
  * declaracoes). Palavras reservadas nao precisam de lexema; identificadores
  * sao guardados na tabela de identificadores. */
{LETRA}{ALFANUM}*   {
                        TokenType token = busca_palavra_reservada(yytext);
                        if (token == ID) {
                            microc_yylval.symbol = tabela_adiciona(&tabela_ids, yytext, yyleng);
                        }
                        RETORNA(token);
                    }

 /* --- Constantes inteiras -----------------------------------------------
  * O texto completo do literal e guardado na tabela de inteiros, sem
  * converter para numero: o enunciado nao pede checagem de estouro e zeros
  * a esquerda sao preservados. Uma sequencia como 123abc gera INTEGERCONST
  * seguido de ID, pois nao e um erro lexico. */
{DIGIT}+            {
                        microc_yylval.symbol = tabela_adiciona(&tabela_inteiros, yytext, yyleng);
                        RETORNA(INTEGERCONST);
                    }

 /* Inteiro negativo: sinal de menos colado em digitos, sem espaco.
  * Pelo casamento mais longo, esta regra vence a regra do "-" sozinho
  * sempre que ha digitos logo depois. Na acao olhamos o token anterior
  * (ver secao 5 das declaracoes):
  *   - se ele termina um operando (ex.: em x-1), o "-" e subtracao:
  *     yyless(1) mantem so o primeiro caractere (o sinal) no token atual
  *     e devolve os digitos para a entrada, que serao lidos na proxima
  *     chamada como uma constante separada; devolvemos MINUS.
  *   - senao (ex.: em x = -1), e uma constante negativa: guardamos o texto
  *     com o sinal e devolvemos INTEGERCONST. */
"-"{DIGIT}+         {
                        if (termina_operando(ultimo_token)) {
                            yyless(1);
                            RETORNA(MINUS);
                        }
                        microc_yylval.symbol = tabela_adiciona(&tabela_inteiros, yytext, yyleng);
                        RETORNA(INTEGERCONST);
                    }

 /* --- Constantes de caractere ---------------------------------------------
  * Formas validas: um caractere entre apostrofos (exceto apostrofo, barra
  * invertida e quebra de linha), ou uma barra invertida seguida de qualquer
  * caractere exceto quebra de linha (escape). O valor guardado e sempre 1
  * byte, ja convertido, na tabela de strings.
  *
  * ORDEM IMPORTA: as duas regras validas vem ANTES das regras de erro.
  * Um caractere entre apostrofos casa 3 caracteres tanto na regra valida
  * quanto na regra de "invalida"; no empate vence a que aparece primeiro.
  * O mesmo acontece com um escape de barra dupla entre apostrofos (4
  * caracteres nas duas regras).
  *
  * Erros (as mensagens foram definidas por nos):
  *   - apostrofos vazios ou com mais de um caractere dentro: invalida;
  *   - apostrofo sem outro apostrofo ate o fim da linha: nao terminada.
  *     Essa regra nao consome a quebra de linha, que continua sendo contada
  *     pela regra da quebra de linha. */
'[^'\\\n]'          {
                        microc_yylval.symbol = tabela_adiciona(&tabela_strings, yytext + 1, 1);
                        RETORNA(CHARCONST);
                    }
'\\[^\n]'           {
                        char valor = converte_escape(yytext[2]);
                        microc_yylval.symbol = tabela_adiciona(&tabela_strings, &valor, 1);
                        RETORNA(CHARCONST);
                    }
'[^'\n]*'           {
                        microc_yylval.error_msg = MSG_CHAR_INVALIDA;
                        RETORNA(UNDEF);
                    }
'[^'\n]*            {
                        microc_yylval.error_msg = MSG_CHAR_NAO_TERM;
                        RETORNA(UNDEF);
                    }

 /* --- Constantes de string ---------------------------------------------
  * A aspa de abertura liga o estado EM_STRING. Dentro dele o conteudo e
  * lido em pedacos e os bytes, ja convertidos, sao acumulados no buffer
  * dinamico (secao 7 das declaracoes). O token so e devolvido quando a
  * string termina.
  *
  * Tratamento de erros (Secao 4.1 do enunciado):
  *   - quebra de linha NAO escapada antes do fechamento:
  *       "String nao terminada", e a leitura continua na linha seguinte;
  *   - EOF antes do fechamento: "EOF em string";
  *   - byte nulo literal (valor 0 no arquivo) em qualquer ponto da string:
  *       "String contem caractere nulo". Continuamos lendo ate a string
  *       terminar (aspa, quebra de linha ou EOF), reconhecendo os escapes
  *       para que uma aspa escapada nao feche a string, e devolvemos um
  *       UNICO erro, que tem prioridade sobre os outros dois.
  *
  * Observacao: o escape \0 escrito no fonte (barra + digito zero) e VALIDO
  * e vira um byte nulo dentro do valor; so o byte nulo literal e erro. */
\"                  {
                        string_inicia();
                        BEGIN(EM_STRING);
                    }

 /* Aspa de fechamento: fim normal da string. */
<EM_STRING>\"       {
                        BEGIN(INITIAL);
                        if (string_tem_nulo) {
                            microc_yylval.error_msg = MSG_STRING_NULO;
                            RETORNA(UNDEF);
                        }
                        microc_yylval.symbol = tabela_adiciona(&tabela_strings, string_buffer, string_tamanho);
                        RETORNA(STRINGCONST);
                    }

 /* Trecho de texto comum (sem aspa, barra invertida ou quebra de linha).
  * A classe de caracteres tambem casa o byte nulo, por isso procuramos um
  * byte nulo no trecho com memchr antes de guardar. */
<EM_STRING>[^"\\\n]+ {
                        if (memchr(yytext, '\0', (size_t) yyleng) != NULL) {
                            string_tem_nulo = 1;
                        } else {
                            string_acrescenta(yytext, yyleng);
                        }
                    }

 /* Quebra de linha escapada (barra invertida no fim da linha, inclusive
  * com fim de linha do Windows): e permitida, vira um byte de nova linha no
  * valor e conta a linha. Assim a string pode se estender por varias linhas,
  * e o token e reportado na linha em que termina. */
<EM_STRING>\\\r?\n  {
                        string_acrescenta("\n", 1);
                        linha_atual++;
                    }

 /* Barra invertida seguida de outro caractere: sequencia de escape.
  * O ponto tambem casa o byte nulo; uma barra seguida de byte nulo literal
  * torna a string invalida. */
<EM_STRING>\\.      {
                        if (yytext[1] == '\0') {
                            string_tem_nulo = 1;
                        } else {
                            char valor = converte_escape(yytext[1]);
                            string_acrescenta(&valor, 1);
                        }
                    }

 /* Barra invertida sozinha. Qualquer caractere depois dela faria uma das
  * duas regras anteriores casar 2 ou 3 caracteres, entao esta regra so vence
  * quando a barra e o ultimo byte do arquivo. Nao faz nada: em seguida o
  * <<EOF>> abaixo reporta o erro. Sem ela a especificacao ficaria incompleta. */
<EM_STRING>\\       { }

 /* Quebra de linha NAO escapada: string nao terminada.
  * yyless(0) devolve a quebra de linha para a entrada e BEGIN(INITIAL) sai
  * da string; assim a quebra de linha e lida de novo pela regra normal, que
  * incrementa a linha. Resultado: o erro e reportado na linha da propria
  * string e a leitura continua no caractere seguinte a quebra de linha.
  * (Um yyless(0) SEM trocar de estado reanalisaria o mesmo texto na mesma
  * regra para sempre.) */
<EM_STRING>\n       {
                        BEGIN(INITIAL);
                        yyless(0);
                        if (string_tem_nulo) {
                            microc_yylval.error_msg = MSG_STRING_NULO;
                        } else {
                            microc_yylval.error_msg = MSG_STRING_NAO_TERM;
                        }
                        RETORNA(UNDEF);
                    }

 /* EOF dentro da string. Assim como no comentario, voltamos ao INITIAL antes
  * de retornar, para que a proxima chamada devolva END_OF_FILE (sem loop). */
<EM_STRING><<EOF>>  {
                        BEGIN(INITIAL);
                        if (string_tem_nulo) {
                            microc_yylval.error_msg = MSG_STRING_NULO;
                        } else {
                            microc_yylval.error_msg = MSG_EOF_STRING;
                        }
                        RETORNA(UNDEF);
                    }

 /* --- Operadores relacionais e logicos ---------------------------------
  * Operadores que compartilham prefixo sao escritos como regras separadas;
  * o casamento mais longo escolhe a certa (ex.: "<=" vence "<").
  * Um "&" ou "|" sozinho nao e operador de Micro C: cai na regra de
  * caractere invalido no fim do arquivo. */
"=="                { RETORNA(EQ); }
"="                 { RETORNA(ASSIGN); }
"!="                { RETORNA(NEQ); }
"!"                 { RETORNA(NOT); }
"<="                { RETORNA(LEQ); }
"<"                 { RETORNA(LT); }
">="                { RETORNA(GEQ); }
">"                 { RETORNA(GT); }
"&&"                { RETORNA(AND); }
"||"                { RETORNA(OR); }

 /* --- Operadores aritmeticos e simbolos de pontuacao ------------------ */
"+"                 { RETORNA(PLUS); }
"-"                 { RETORNA(MINUS); }
"*"                 { RETORNA(MUL); }
"/"                 { RETORNA(DIV); }
"%"                 { RETORNA(MOD); }
";"                 { RETORNA(SEMICOLON); }
","                 { RETORNA(COMMA); }
"("                 { RETORNA(LPAREN); }
")"                 { RETORNA(RPAREN); }
"{"                 { RETORNA(LBRACE); }
"}"                 { RETORNA(RBRACE); }
"["                 { RETORNA(LBRACKET); }
"]"                 { RETORNA(RBRACKET); }

 /* --- Caractere invalido -------------------------------------------------
  * Casa com qualquer caractere que nao tenha correspondido a nenhuma
  * regra anterior (ex.: @, #, $, bytes nao ASCII, byte nulo fora de string).
  * O lexema de erro e uma string contendo apenas esse caractere, e a leitura
  * continua no caractere seguinte. Deve ser SEMPRE a ultima regra: no empate
  * de 1 caractere, qualquer regra anterior vence esta. */
.                   {
                        caractere_invalido[0] = yytext[0];
                        caractere_invalido[1] = '\0';
                        microc_yylval.error_msg = caractere_invalido;
                        RETORNA(UNDEF);
                    }

%%

/* -----------------------------------------------------------------------
 * SUB-ROTINAS DO USUARIO
 * ------------------------------------------------------------------- */

/* yywrap: informa ao flex que, ao atingir o EOF, a leitura deve
 * simplesmente parar (nao ha um proximo arquivo a processar). */
int yywrap(void) {
    return 1;
}

/* main() de teste: le o arquivo passado como argumento e imprime, para
 * cada token reconhecido, seu tipo, lexema e linha -- no mesmo espirito
 * do utilitario "lexer" mencionado no enunciado (Secao 6). Este main()
 * e apenas uma ferramenta de depuracao para testar o scanner de forma
 * isolada; ele NAO faz parte da interface formal entre o scanner e o
 * parser (isso sera tratado nos trabalhos seguintes).
 *
 * Ajustes em relacao ao esqueleto:
 *   - Para ID, INTEGERCONST, CHARCONST e STRINGCONST o lexema e impresso a
 *     partir da tabela de strings (microc_yylval.symbol), e nao de yytext:
 *     numa constante de caractere yytext inclui os apostrofos; numa string
 *     lida em pedacos, yytext contem so o ultimo pedaco (a aspa final); e o
 *     valor ja convertido pode conter byte nulo. Por isso usamos fwrite com
 *     o tamanho guardado. A saida continua exatamente no mesmo formato. O
 *     valor e impresso ja convertido: um \n convertido quebra a linha.
 *   - fflush(stdout) antes de cada erro, para que tokens (stdout) e erros
 *     (stderr) saiam na ordem certa mesmo com a saida redirecionada.
 *   - No final, a memoria do scanner e liberada. */
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo.mc>\n", argv[0]);
        return 1;
    }

    FILE *arquivo_fonte = fopen(argv[1], "r");
    if (!arquivo_fonte) {
        fprintf(stderr, "Erro: nao foi possivel abrir o arquivo '%s'\n", argv[1]);
        return 1;
    }
    yyin = arquivo_fonte;

    int tipo;
    while ((tipo = yylex()) != END_OF_FILE) {
        if (tipo == UNDEF) {
            fflush(stdout);
            fprintf(stderr, "ERRO LEXICO (linha %d): %s\n",
                    linha_atual, microc_yylval.error_msg);
            continue;
        }
        printf("Token: tipo = %-13s lexema = '", nome_token[tipo]);
        if (tipo == ID || tipo == INTEGERCONST || tipo == CHARCONST || tipo == STRINGCONST) {
            fwrite(microc_yylval.symbol->texto, 1, (size_t) microc_yylval.symbol->tamanho, stdout);
        } else {
            fputs(yytext, stdout);
        }
        printf("'  linha = %d\n", linha_atual);
    }

    fclose(arquivo_fonte);
    yylex_destroy();            /* libera os buffers internos do flex */
    libera_memoria_scanner();   /* libera tabelas de strings e buffer  */
    return 0;
}
