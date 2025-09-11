#include "plugin_common.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

const char* expander_transform(const char* s) {
    if (!s) return NULL;
    
    int l = strlen(s);
    if (l == 0) {
        char* out = strdup(s);
        if (!out) {
            fprintf(stderr, "ERROR: expander failed to allocate memory\n");
            exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
        }
        return out;
    }
    
    char* r = malloc(l * 2);
    if (!r) {
        fprintf(stderr, "ERROR: expander failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }
    
    int j = 0;
    for (int i = 0; i < l; i++) {
        r[j++] = s[i];  
        if (i < l - 1) {
            r[j++] = ' ';
        }
    }
    r[j] = '\0';
    
    return r;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(expander_transform, "expander", qsize);
}
