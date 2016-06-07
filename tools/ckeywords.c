/* Copyright 2015, NICTA
 *
 * This software may be distributed and modified according to the terms of
 * the BSD 2-Clause license. Note that NO WARRANTY is provided.
 * See "LICENSE_BSD2.txt" for details.
 *
 * @TAG(NICTA_BSD)
 */

/* Utility for constructing a Python set of C keywords.
 *
 * When performing code generation based on a user's input specification, it is
 * desirable to give them some friendly feedback when they've used an
 * identifier that will result in emitting code that clashes with built-in C
 * keywords. To do this, we could manually enumerate the C keywords, but this
 * is a little error prone. Instead, it is simpler and more robust to just ask
 * a C compiler what keywords it recognises.
 *
 * I could not immediately see a straightforward way to do this with GCC, but
 * Clang provides TokenKinds.def, a file conveniently setup for the X macro
 * trick. Note that to build this program, you will need the Clang sources
 * available. Compile it with:
 *
 *     cc -std=c11 -W -Wall -Wextra \
 *       -I/path/to/clang/include/clang/Basic/TokenKinds.def ckeywords.c
 *
 * To run the generated program and update the Python source file for the AST
 * module:
 *
 *    ./a.out >../camkes/ast/ckeywords.py
 */

#include <regex.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Characteristics of the environment we are targeting. See Clang sources for
 * the meaning of these constants.
 */
#define KEYALL       1
#define KEYC99       1
#define KEYC11       1
#define KEYCXX       0
#define KEYNOCXX     1
#define KEYCXX11     0
#define KEYGNU       1
#define KEYMS        0
#define KEYNOMS      0
#define KEYNOMS18    0
#define KEYOPENCL    0
#define KEYNOOPENCL  1
#define KEYALTIVEC   0
#define KEYARC       0
#define KEYBORLAND   0
#define BOOLSUPPORT  1
#define HALFSUPPORT  0
#define WCHARSUPPORT 1

/* Turn a symbol into a string. */
#define _stringify(x) #x
#define stringify(x) _stringify(x)

/* Both `KEYWORD` and `ALIAS` below will bottom out in calls to this macro. We
 * will go on to use the emitted code as entries of the `keywords` array below.
 */
#define KEYWORD_(string, category) (category) ? string : NULL,

/* These macros are called in TokenKinds.def. */
#define KEYWORD(word, category) KEYWORD_(stringify(word), category)
#define ALIAS(string, target, category) KEYWORD_(string, category)

static char *keywords[] = {
/* Include Clang's definition of keywords.
 *  include/clang/Basic/TokenKinds.def
 */
#include <TokenKinds.def>
};

static const char *indent = "    ";
static const unsigned wrap_at = 80; /* characters */
static const char *header = "#!/usr/bin/env python\n"
                            "# -*- coding: utf-8 -*-\n"
                            "\n"
                            "#\n"
                            "# Copyright 2015, NICTA\n"
                            "#\n"
                            "# This software may be distributed and modified according to the terms of\n"
                            "# the BSD 2-Clause license. Note that NO WARRANTY is provided.\n"
                            "# See \"LICENSE_BSD2.txt\" for details.\n"
                            "#\n"
                            "# @TAG(NICTA_BSD)\n"
                            "#\n"
                            "\n"
                            "# Generated by ckeywords.c. Do not edit manually.\n"
                            "\n"
                            "from __future__ import absolute_import, division, print_function, \\\n"
                            "    unicode_literals\n"
                            "from camkes.internal.seven import cmp, filter, map, zip\n"
                            "\n"
                            "# A list of C keywords for the purpose of warning the user when a symbol in\n"
                            "# their input specification is likely to cause compiler errors.\n"
                            "C_KEYWORDS = frozenset([\n";
static const char *footer = "])\n";

int main(void) {
    bool newline = true;
    unsigned column = 0;

    /* Construct a regex that matches CAmkES identifiers. */
    regex_t regex;
    if (regcomp(&regex, "^[a-zA-Z_][a-zA-Z0-9_]*", 0) != 0) {
        perror("failed to compile regex");
        return EXIT_FAILURE;
    }

    printf("%s", header);

    for (unsigned i = 0; i < sizeof(keywords) / sizeof(keywords[0]); i++) {

        /* This keyword was irrelevant in our current environment. */
        if (keywords[i] == NULL)
            continue;

        /* Keyword that can never collide with a CAmkES identifier. */
        if (regexec(&regex, keywords[i], 0, NULL, 0) == REG_NOMATCH)
            continue;

        unsigned len = strlen(keywords[i]);
        if (column + len + 4 > wrap_at) {
            printf("\n");
            column = 0;
            newline = true;
        }

        if (newline) {
            printf("%s", indent);
            newline = false;
            column += strlen(indent);
        } else {
            printf(" ");
        }

        printf("'%s',", keywords[i]);
        column += len + 4;
    }

    regfree(&regex);

    printf("\n%s", footer);

    return EXIT_SUCCESS;
}
