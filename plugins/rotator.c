#include "plugin_common.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

const char* rotator_transform(const char* s) {
    if (!s) return NULL;
    
    int l = strlen(s);
    if (l <= 1) {
        char* out = strdup(s);
        if (!out) {
            fprintf(stderr, "ERROR: rotator failed to allocate memory\n");
            exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
        }
        return out;
    }
    
    char* r = malloc(l + 1);
    if (!r) {
        fprintf(stderr, "ERROR: rotator failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }

    r[0] = s[l - 1];
    memcpy(r + 1, s, l - 1);
    r[l] = '\0';
    
    return r;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(rotator_transform, "rotator", qsize);
}