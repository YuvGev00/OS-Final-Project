#include "plugin_common.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

const char* flipper_transform(const char* s) {
    if (!s) return NULL;
    
    int l = strlen(s);
    char* r = malloc(l + 1);
    if (!r) {
        fprintf(stderr, "ERROR: flipper failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }

    for (int i = 0; i < l; i++) {
        r[i] = s[l - 1 - i];
    }
    r[l] = '\0';
    
    return r;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(flipper_transform, "flipper", qsize);
}