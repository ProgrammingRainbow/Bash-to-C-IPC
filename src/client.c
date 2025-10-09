#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define SHM_DATA_PATH "/dev/shm/my_shared_data"
#define SHM_LOCK_PATH "/dev/shm/my_shared_lock"

#define BUFFER_SIZE 64

typedef struct {
        int fd_shm_data;
        int fd_shm_lock;
        volatile char *shm_data;
        volatile char *shm_lock;
} SharedClient;

void shared_client_free(SharedClient *s);
bool shared_client_run(const char *str);

void shared_client_free(SharedClient *s) {
    if (s) {
        // Unmap the shared data memory region.
        if (s->shm_data) {
            munmap((void *)s->shm_data, BUFFER_SIZE);
            s->shm_data = NULL;
        }

        // Unmap the shared lock memory region.
        if (s->shm_lock) {
            munmap((void *)s->shm_lock, BUFFER_SIZE);
            s->shm_lock = NULL;
        }

        // Close the file descriptor for shared data.
        if (s->fd_shm_data >= 0) {
            close(s->fd_shm_data);
            s->fd_shm_data = -1;
        }

        // Close the file descriptor for shared lock.
        if (s->fd_shm_lock >= 0) {
            close(s->fd_shm_lock);
            s->fd_shm_lock = -1;
        }
    }
}

bool shared_client_run(const char *str) {
    SharedClient s = {0};

    // Open the shared memory data file for reading and writing.
    s.fd_shm_data = open(SHM_DATA_PATH, O_RDWR);
    if (s.fd_shm_data < 0) {
        perror("[SERVER] Error: Opening shared memory file.");
        shared_client_free(&s);
        return false;
    }

    // Open the shared memory lock file for reading and writing.
    s.fd_shm_lock = open(SHM_LOCK_PATH, O_RDWR);
    if (s.fd_shm_lock < 0) {
        perror("[SERVER] Error: Opening shared memory file.");
        shared_client_free(&s);
        return false;
    }

    // Map the shared data file into memory for read/write access
    s.shm_data = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                      s.fd_shm_data, 0);
    if (s.shm_data == MAP_FAILED) {
        perror("[SERVER] Error: Mmaping shared memory data file.");
        shared_client_free(&s);
        return false;
    }

    // Map the shared lock file into memory for read/write access
    s.shm_lock = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                      s.fd_shm_lock, 0);
    if (s.shm_lock == MAP_FAILED) {
        perror("[SERVER] Error: Mmaping shared memory lock file.");
        shared_client_free(&s);
        return false;
    }

    // The client only sends/receices once, nanosleep is not needed.
    // struct timespec ts = {0, 1000};

    // Shared memory lock uses the first char only.
    // 0 client can write, 1 server can read/write,
    // 2 client can read, and 3 server shut down.

    // Check if "shutdown" was sent.
    if (!strcmp(str, "shutdown")) {
        s.shm_lock[0] = 3;
    } else {
        while (true) {
            if (s.shm_lock[0] == 0) {
                // Use snprintf or memcopy to send str to shared memory data.
                // snprintf((char *)s.shm_data, BUFFER_SIZE, "%s", str);
                memcpy((char *)s.shm_data, str, strlen(str) + 1);
                s.shm_lock[0] = 1;
                while (true) {
                    if (s.shm_lock[0] == 2) {
                        // printf("%s\n", (char *)s.shm_data);
                        puts((char *)s.shm_data);
                        s.shm_lock[0] = 0;
                        break;
                    }
                    // nanosleep(&ts, NULL);
                }
                break;
            }
            // nanosleep(&ts, NULL);
        }
    }

    shared_client_free(&s);

    return true;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Error: %s requires an argument.\n", argv[0]);
        return EXIT_FAILURE;
    }

    if (!shared_client_run(argv[1])) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
