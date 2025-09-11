#include "monitor.h"

int monitor_init(monitor_t* m) {
    if (m == NULL) {
        return -1;
    }
    
    m->signaled = 0;
    
    if (pthread_mutex_init(&m->mutex, NULL) != 0) {
        return -1;
    }
    
    if (pthread_cond_init(&m->condition, NULL) != 0) {
        pthread_mutex_destroy(&m->mutex);
        return -1;
    }
    
    return 0;
}

void monitor_destroy(monitor_t* m) {
    if (m == NULL) {
        return;
    }
    
    pthread_mutex_destroy(&m->mutex);
    pthread_cond_destroy(&m->condition);
}

void monitor_signal(monitor_t* m) {
    if (m == NULL) {
        return;
    }
    
    pthread_mutex_lock(&m->mutex);
    m->signaled = 1;
    pthread_cond_signal(&m->condition);
    pthread_mutex_unlock(&m->mutex);
}

void monitor_reset(monitor_t* m) {
    if (m == NULL) {
        return;
    }
    
    pthread_mutex_lock(&m->mutex);
    m->signaled = 0;
    pthread_mutex_unlock(&m->mutex);
}

int monitor_wait(monitor_t* m) {
    if (m == NULL) {
        return -1;
    }
    
    pthread_mutex_lock(&m->mutex);
    
    while (!m->signaled) { // prevents lost signals
        if (pthread_cond_wait(&m->condition, &m->mutex) != 0) {
            pthread_mutex_unlock(&m->mutex);
            return -1;
        }
    }
    
    pthread_mutex_unlock(&m->mutex);
    return 0;
}

