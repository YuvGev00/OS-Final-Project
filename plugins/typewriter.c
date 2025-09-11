#include "plugin_common.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

const char* typewriter_transform(const char* s) {
    if (!s) return NULL;
    
    const char* prefix = "[typewriter] ";
    for (int i = 0; prefix[i] != '\0'; i++) {
        usleep(100000); 
        printf("%c", prefix[i]);
        fflush(stdout); 
    }
    
    for (int i = 0; s[i] != '\0'; i++) {
        usleep(100000); 
        printf("%c", s[i]);
        fflush(stdout);  
    }
    
    printf("\n");
    fflush(stdout);

    char* out = strdup(s);
    if (!out) {
        fprintf(stderr, "ERROR: typewriter failed to allocate memory\n");
        exit(1); // exit on malloc or critical (not forbidden - pizza @520 , @531_f1)
    }
    return out;
}

const char* plugin_init(int qsize) {
    return common_plugin_init(typewriter_transform, "typewriter", qsize);
}
