#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>

// MY IMPLEMENTATION ONLY SUPPORTS ONE INSTANCE PER PLUGIN !!!

typedef const char* (*plugin_init_func_t)(int);
typedef const char* (*plugin_fini_func_t)(void);
typedef const char* (*plugin_place_work_func_t)(const char*);
typedef void (*plugin_attach_func_t)(const char* (*)(const char*));
typedef const char* (*plugin_wait_finished_func_t)(void);

typedef struct {
    plugin_init_func_t init;
    plugin_fini_func_t fini;
    plugin_place_work_func_t place_work;
    plugin_attach_func_t attach;
    plugin_wait_finished_func_t wait_finished;
    char* name;
    void* handle;
} plugin_handle_t;

//helper Functions

/*
analyzer path depends on implementation ( argv[0]). 
to grader : notice that the usage will return the message with argv[0](analyzer_path),
            and not hardcoded ./analyzer like in pdf... (piazza @401)
*/
void print_usage(const char* analyzer_path) {
    printf("Usage: %s <queue_size> <plugin1> <plugin2> ... <pluginN>\n", analyzer_path);
    printf("Arguments:\n");
    printf("  queue_size Maximum number of items in each plugin's queue\n");
    printf("  plugin1..N Names of plugins to load (without .so extension)\n");
    printf("Available plugins:\n");
    printf("  logger - Logs all strings that pass through\n");
    printf("  typewriter - Simulates typewriter effect with delays\n");
    printf("  uppercaser - Converts strings to uppercase\n");
    printf("  rotator - Move every character to the right. Last character moves to the beginning.\n");
    printf("  flipper - Reverses the order of characters\n");
    printf("  expander - Expands each character with spaces\n");
    printf("Example:\n");
    printf("  %s 20 uppercaser rotator logger\n", analyzer_path);
    printf("  echo 'hello' | %s 20 uppercaser rotator logger\n", analyzer_path);
    printf("  echo '<END>' | %s 20 uppercaser rotator logger\n", analyzer_path);
}


int validate_args(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Error: Invalid number of arguments\n");
        return -1;
    }
    
    char* endptr;
    int qsize = strtol(argv[1], &endptr, 10);
    
    if (*endptr != '\0' || qsize <= 0) {
        fprintf(stderr, "Error: Invalid queue size\n");
        return -1;
    }
    
    return qsize;
}

char* plugin_path(const char* plugin_name) { // from both root and output dir
    static char path[256];
    
    snprintf(path, sizeof(path), "./%s.so", plugin_name);
    if (access(path, F_OK) == 0) {
        return path;
    }
    
    snprintf(path, sizeof(path), "./output/%s.so", plugin_name);
    return path;
}


int load_plugin(plugin_handle_t* p, const char* plugin_name) {
    char* filename = plugin_path(plugin_name);
    
    p->handle = dlopen(filename, RTLD_NOW | RTLD_LOCAL);
    if (!p->handle) {
        fprintf(stderr, "Error: Failed to load plugin %s: %s\n", plugin_name, dlerror());
        return -1;
    }
    
    dlerror(); 
    
    p->init = dlsym(p->handle, "plugin_init");
    p->fini = dlsym(p->handle, "plugin_fini");
    p->place_work = dlsym(p->handle, "plugin_place_work");
    p->attach = dlsym(p->handle, "plugin_attach");
    p->wait_finished = dlsym(p->handle, "plugin_wait_finished");
    const char* (*get_name)(void) = dlsym(p->handle, "plugin_get_name");
    
    const char* err = dlerror();
    if (err != NULL || !p->init || !p->fini || !p->place_work || !p->attach || !p->wait_finished || !get_name) {
        fprintf(stderr, "Error: Plugin %s does not implement required interface\n", plugin_name);
        dlclose(p->handle);
        p->handle = NULL;
        return -1;
    }

    const char* actual_name = get_name();
    p->name = strdup(actual_name);
    if (!p->name) {
        fprintf(stderr, "Error: Failed to allocate memory for plugin name\n");
        dlclose(p->handle);
        p->handle = NULL;       
        return -1;
    }
    
    return 0;
}

int initialize_plugins(plugin_handle_t* p, int count, int qsize) {
    for (int i = 0; i < count; i++) {
        const char* err = p[i].init(qsize);
        if (err) { // start garceful cleanup
            fprintf(stderr, "Error: Failed to initialize plugin %s: %s\n", p[i].name, err);
            for (int j = 0; j < i; j++) {
                p[j].place_work("<END>");
            }
            
            for (int j = 0; j < i; j++) {
                p[j].wait_finished();
            }
            
            for (int j = 0; j < i; j++) {
                p[j].fini();
            }
            
            return -1;
        }
    }
    return 0;
}

void connect_plugin_chain(plugin_handle_t* p, int count) {
    for (int i = 0; i < count - 1; i++) {
        p[i].attach(p[i + 1].place_work);
    }
}

void process_input(plugin_handle_t* first_plugin) {
    char buf[1026];
    while (fgets(buf, sizeof(buf), stdin)) {
        size_t len = strlen(buf);

        if (len == 1025 && buf[len-1] != '\n') {
            fprintf(stderr, "Error: Input line exceeds maximum length of 1024 characters\n");
            exit(1);
        }


        if (len > 0 && buf[len - 1] == '\n') {
            buf[len - 1] = '\0';
        }
        
        const char* err = first_plugin->place_work(buf);
        if (err) {
            fprintf(stderr, "Error: Failed to place work: %s\n", err);
        }
        
        if (strcmp(buf, "<END>") == 0) {
            break;
        }
    }

}

void wait_for_plugins(plugin_handle_t* p, int count) {
    for (int i = 0; i < count; i++) {
        const char* err = p[i].wait_finished();
        if (err) {
            fprintf(stderr, "Error: Failed to wait for plugin %s: %s\n", p[i].name, err);
        }
    }
}

void finalize_plugins(plugin_handle_t* p, int count) {
    for (int i = 0; i < count; i++) {
        const char* err = p[i].fini();
        if (err) {
            fprintf(stderr, "Error: Failed to finalize plugin %s: %s\n", p[i].name, err);
        }
    }
}

void cleanup_plugins(plugin_handle_t* p, int count) {
    if (!p) return;
    
    for (int i = 0; i < count; i++) {
        if (p[i].handle) {
            dlclose(p[i].handle);
        }
        if (p[i].name) {
            free(p[i].name);
        }
    }
    free(p);
}

//main

int main(int argc, char* argv[]) {
    int qsize = validate_args(argc, argv);
    if (qsize < 0) {
        print_usage(argv[0]);
        return 1;
    }
    
    int n = argc - 2;
    plugin_handle_t* p = calloc(n, sizeof(plugin_handle_t));
    
    if (!p) {
        fprintf(stderr, "Error: Failed to allocate memory\n");
        return 1;
    }
    
    for (int i = 0; i < n; i++) {
        if (load_plugin(&p[i], argv[i + 2]) < 0) {
            cleanup_plugins(p, i);
            print_usage(argv[0]);
            return 1;
        }
    }
    
    if (initialize_plugins(p, n, qsize) < 0) {
        cleanup_plugins(p, n);
        return 2;
    }
    
    connect_plugin_chain(p, n);
    process_input(&p[0]);
    wait_for_plugins(p, n);
    finalize_plugins(p, n);
    cleanup_plugins(p, n);
    
    printf("Pipeline shutdown complete\n");
    return 0;
}