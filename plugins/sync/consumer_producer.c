#include "consumer_producer.h"
#include <stdlib.h>
#include <string.h>
#include <pthread.h>


void free_remaining_items(consumer_producer_t* q) {
    while (q->count > 0) {
        free(q->items[q->head]);
        q->head = (q->head + 1) % q->capacity;
        q->count--;
    }
}

void cleanup_init_failure(consumer_producer_t* q, int monitors_initialized) {
    free(q->items);
    if (monitors_initialized >= 3) monitor_destroy(&q->finished_monitor);
    if (monitors_initialized >= 2) monitor_destroy(&q->not_empty_monitor);
    if (monitors_initialized >= 1) monitor_destroy(&q->not_full_monitor);
    pthread_mutex_destroy(&q->mutex);
}

const char* consumer_producer_init(consumer_producer_t* q, int cap) {
    if (q == NULL) {
        return "Queue pointer is NULL";
    }
    if (cap <= 0) {
        return "Invalid capacity";
    }
    
    if (pthread_mutex_init(&q->mutex, NULL) != 0) {
        return "Failed to initialize queue mutex";
    }
    
    q->items = malloc(cap * sizeof(char*));
    if (!q->items) {
        pthread_mutex_destroy(&q->mutex);
        return "Failed to allocate memory for queue items";
    }
    
    q->capacity = cap;
    q->count = 0;
    q->head = 0;
    q->tail = 0;
    
    if (monitor_init(&q->not_full_monitor) != 0) {
        cleanup_init_failure(q, 0);
        return "Failed to initialize not_full_monitor";
    }
    
    if (monitor_init(&q->not_empty_monitor) != 0) {
        cleanup_init_failure(q, 1);
        return "Failed to initialize not_empty_monitor";
    }
    
    if (monitor_init(&q->finished_monitor) != 0) {
        cleanup_init_failure(q, 2);
        return "Failed to initialize finished_monitor";
    }
    
    monitor_signal(&q->not_full_monitor);
    
    return NULL;
}

void consumer_producer_destroy(consumer_producer_t* q) {
    if (q == NULL) return;
    
    pthread_mutex_lock(&q->mutex);
    free_remaining_items(q);
    pthread_mutex_unlock(&q->mutex);
    
    free(q->items);
    monitor_destroy(&q->not_full_monitor);
    monitor_destroy(&q->not_empty_monitor);
    monitor_destroy(&q->finished_monitor);
    pthread_mutex_destroy(&q->mutex);
}

const char* consumer_producer_put(consumer_producer_t* q, const char* s) {
    if (q == NULL) {
        return "Queue is NULL";
    }
    if (s == NULL) {
        return "String is NULL";
    }
    
    pthread_mutex_lock(&q->mutex);
    
    while (q->count == q->capacity) {  // wait if queue full
        monitor_reset(&q->not_full_monitor);
        pthread_mutex_unlock(&q->mutex);  // release mutex during wait to allow other threads to modify queue
        if (monitor_wait(&q->not_full_monitor) != 0) {
            return "Failed to wait for queue space";
        }  
        pthread_mutex_lock(&q->mutex);
    }
    
    q->items[q->tail] = strdup(s); // queue takes ownership (caller can free original)
    if (!q->items[q->tail]) {
        pthread_mutex_unlock(&q->mutex);
        return "Failed to duplicate string";
    }
    
    q->tail = (q->tail + 1) % q->capacity;
    q->count++;
    
    monitor_signal(&q->not_empty_monitor);
    if (q->count < q->capacity) {
        monitor_signal(&q->not_full_monitor);
    }
    
    pthread_mutex_unlock(&q->mutex);
    return NULL;
}

char* consumer_producer_get(consumer_producer_t* q) {
    if (q == NULL) {
        return NULL;
    }
    
    pthread_mutex_lock(&q->mutex);
    
    while (q->count == 0) {
        monitor_reset(&q->not_empty_monitor);
        pthread_mutex_unlock(&q->mutex);
        if (monitor_wait(&q->not_empty_monitor) != 0) {
            return NULL;
        }
        pthread_mutex_lock(&q->mutex);
    }
    
    char* item = q->items[q->head];
    q->head = (q->head + 1) % q->capacity;
    q->count--;
    
    monitor_signal(&q->not_full_monitor); 
    if (q->count > 0) {
        monitor_signal(&q->not_empty_monitor);
    }
    
    pthread_mutex_unlock(&q->mutex);
    return item;
}

void consumer_producer_signal_finished(consumer_producer_t* q) {
    if (q == NULL) return;
    monitor_signal(&q->finished_monitor);
}

int consumer_producer_wait_finished(consumer_producer_t* q) {
    if (q == NULL) {
        return -1;
    }
    return monitor_wait(&q->finished_monitor);
}