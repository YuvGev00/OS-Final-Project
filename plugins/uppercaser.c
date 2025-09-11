#include "plugin_common.h"
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>

const char* uppercaser_transform(const char* input) {
    if (!input) return NULL; 
    
    char* s = strdup(input);
    if (!s) {
        fprintf(stderr, "ERROR: uppercaser failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }

    for (int i = 0; s[i]; i++) {
        s[i] = toupper((unsigned char)s[i]);
    }
    return s;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(uppercaser_transform, "uppercaser", qsize);
}