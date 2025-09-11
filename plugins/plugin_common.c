#include "plugin_common.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#define DEBUG 0  // change to 1 to enable debug output, 0 otherwise

plugin_context_t* ctx = NULL;

void log_error(plugin_context_t* c, const char* msg) {
    #if DEBUG
    fprintf(stderr, "[ERROR][%s] - %s\n", c->name, msg);
    #else
    (void)c; (void)msg;
    #endif
}

void log_info(plugin_context_t* c, const char* msg) {
    #if DEBUG
    fprintf(stdout, "[INFO][%s] - %s\n", c->name, msg);
    #else
    (void)c; (void)msg;
    #endif
}

int process_queue_item(plugin_context_t* c) {
    char* item = consumer_producer_get(c->queue);
    if (!item) {
        log_error(c, "Failed to get item from queue");
        return 1;  
    }
    
    if (strcmp(item, "<END>") == 0) {
        log_info(c, "Received END signal");
        if (c->next_place_work) {
            const char* err = c->next_place_work("<END>"); // send <END> to next plugin
            if (err) {
                log_error(c, err);
            }
        }
        
        free(item);
        return 0; // stop the thread

    }
    
    const char* result = c->process_function(item);
    if (!result) {
        log_error(c, "Process function returned NULL");
        free(item);
        return 0;
    }
    
    if (c->next_place_work && result) {
        const char* err = c->next_place_work(result);
        if (err) {
            log_error(c, err);
        }
    }
    
    free(item); // plugin takes ownership of input, caller free result
    if (result && result != item) {
        free((char*)result);
    }
    
    return 1;
}

void* plugin_consumer_thread(void* arg) {
    plugin_context_t* c = (plugin_context_t*)arg;

    while (process_queue_item(c)) {} // keep going until we get <END>

    consumer_producer_signal_finished(c->queue);
    c->finished = 1;
    log_info(c, "Consumer thread finished");
    
    return NULL;
}

const char* setup_plugin_infrastructure(plugin_context_t* c, int qsize) {
    c->queue = malloc(sizeof(consumer_producer_t));
    if (!c->queue) {
        log_error(c, "Failed to allocate queue");
        return "Failed to allocate queue";
    }

    const char* err = consumer_producer_init(c->queue, qsize);
    if (err) {
        log_error(c, err);
        free(c->queue);
        return err;
    }

    if (pthread_create(&c->consumer_thread, NULL, plugin_consumer_thread, c) != 0) {
        log_error(c, "Failed to create consumer thread");
        consumer_producer_destroy(c->queue);
        free(c->queue);
        return "Failed to create consumer thread";
    }
    
    return NULL;
}

// SDK Functions

__attribute__((visibility("default")))
const char* plugin_get_name(void) {
    return ctx ? ctx->name : "unknown";
}

const char* common_plugin_init(const char* (*proc_func)(const char*), const char* name, int qsize) {
    // check if already initialized (my implementation supports one instance per plugin!!!)
    if (ctx != NULL) {
        return "Plugin already initialized";
    }
    
    ctx = malloc(sizeof(plugin_context_t));
    if (!ctx) {
        return "Failed to allocate plugin context";
    }
    
    ctx->name = name;
    ctx->process_function = proc_func;
    ctx->next_place_work = NULL;
    ctx->initialized = 0;
    ctx->finished = 0;
    
    const char* err = setup_plugin_infrastructure(ctx, qsize);
    if (err) {
        free(ctx);
        ctx = NULL;
        return err;
    }
    
    ctx->initialized = 1;
    log_info(ctx, "Plugin initialized");
    
    return NULL;
}

__attribute__((visibility("default")))
const char* plugin_fini(void) {
    if (!ctx) {
        return NULL; 
    }
    
    if (!ctx->initialized) {
        return NULL; 
    }

    if (pthread_join(ctx->consumer_thread, NULL) != 0) {
        log_error(ctx, "Failed to join consumer thread");
    }

    consumer_producer_destroy(ctx->queue);
    free(ctx->queue);
    free(ctx);
    ctx = NULL;
    
    return NULL;
}

__attribute__((visibility("default")))
const char* plugin_place_work(const char* s) {
    if (!ctx) {
        return "Plugin not initialized";
    }
    
    if (!ctx->initialized) {
        log_error(ctx, "Plugin not initialized");
        return "Plugin not initialized";
    }
    
    if (ctx->finished) {
        log_error(ctx, "Plugin has finished processing");
        return "Plugin has finished processing";
    }

    if (!s) {
        return "NULL string provided"; 
    }

    const char* err = consumer_producer_put(ctx->queue, s);
    if (err) {
        log_error(ctx, err);
    }
    
    return err;
}

__attribute__((visibility("default")))
void plugin_attach(const char* (*next)(const char*)) {
    if (!ctx) {
        return;
    }
    
    ctx->next_place_work = next;
    
    if (next) {
        log_info(ctx, "Attached to next plugin");
    } else {
        log_info(ctx, "No next plugin (last in chain)");
    }
}

__attribute__((visibility("default")))
const char* plugin_wait_finished(void) {
    if (!ctx) {
        return NULL;
    }
    
    if (!ctx->initialized) {
        return NULL;
    }
    
    if (ctx->finished) {
        log_info(ctx, "Plugin already finished");
        return NULL;
    }
    
    log_info(ctx, "Waiting for plugin to finish");
    
    if (consumer_producer_wait_finished(ctx->queue) != 0) {
        log_error(ctx, "Failed to wait for plugin to finish");
        return "Failed to wait for plugin to finish";
    }
    
    return NULL;
}