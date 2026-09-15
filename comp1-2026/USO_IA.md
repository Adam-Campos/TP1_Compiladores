## USO_IA.md

Alunos: Fernando Silva, Maurício Raquita e Adam Rian

Ferramenta: Claude Code (modelo Claude Opus 5, da Anthropic)

Trecho: todos os arquivos da entrega
        - microc.flex (arquivo completo): palavras reservadas, constantes
          inteiras (inclusive negativas), operadores, constantes de
          caractere e de string com sequencias de escape, tratamento de
          todos os erros lexicos, tabela de strings (tabela hash) e
          ajustes no main() de teste
        - test.mc e os arquivos de teste teste_eof_string.mc,
          teste_eof_string_barra.mc, teste_eof_comentario.mc e
          teste_string_nulo.mc
        - README e este arquivo USO_IA.md

Finalidade: com a autorizacao do professor, usamos a IA em etapas:
            1. pedimos que ela lesse o enunciado, o esqueleto e o leiame e
               montasse um prompt com todos os requisitos do trabalho;
            2. pedimos que ela escrevesse a solucao completa seguindo esse
               prompt, compilasse e testasse o scanner;
            3. pedimos um relatorio explicando cada decisao de projeto e um
               guia de estudo, para entendermos o codigo antes da entrevista.
            Nos definimos o que seria pedido em cada etapa, a composicao do
            grupo e a forma de entrega.

O que fizemos com a resposta:
            - nos tres analisamos tudo o que a IA gerou: o microc.flex, os
              arquivos de teste, as saidas dos testes e o relatorio com as
              decisoes de projeto;
            - o codigo foi usado integralmente, sem alteracoes manuais.

Dificuldades encontradas no processo:
            - O enunciado tem pontos contraditorios ou ambiguos que exigiram
              uma decisao: EOF dentro de string ("String nao terminada" ou
              "EOF em string"), nome da funcao (yylex ou microc_yylex),
              quebra de linha escapada dentro de string e o texto das
              mensagens de erro de constante de caractere.
            - A regra <<EOF>> sem estado do esqueleto fazia o flex ignorar a
              regra de EOF em comentario (aviso "multiple <<EOF>> rules"): um
              comentario sem fechamento terminava o arquivo sem erro. Isso so
              apareceu compilando e testando; depois de corrigir, faltar o
              BEGIN(INITIAL) causava loop infinito.
            - Diferenciar constante negativa de operador de subtracao exige
              olhar o token anterior (x-1 e diferente de x = -1).
            - Os casos de EOF e de byte nulo nao cabem num arquivo de texto
              comum e precisaram ser gerados por comando.
            - flex e gcc nao estavam instalados no Windows; os testes foram
              feitos num container Linux (Docker).

O que aprendemos:
            - como o flex escolhe a regra: casamento mais longo e, no empate,
              a regra que aparece primeiro;
            - estados exclusivos (%x), BEGIN, <<EOF>> e yyless;
            - como funciona uma tabela hash com encadeamento usada como
              tabela de strings, e por que guardar o tamanho do lexema;
            - a importancia de testar casos limite (EOF, byte nulo, arquivos
              com fim de linha do Windows) e de tratar avisos do flex como
              erros.
