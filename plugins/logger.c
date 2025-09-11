#include "plugin_common.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

const char* logger_transform(const char* s) {
    if (!s) return NULL;
    
    printf("[logger] %s\n", s);
    fflush(stdout);
    
    char* out = strdup(s);
    if (!out) {
        fprintf(stderr, "ERROR: logger failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }
    return out;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(logger_transform, "logger", qsize);
}
