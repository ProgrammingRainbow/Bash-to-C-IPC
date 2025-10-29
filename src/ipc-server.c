#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>

#define PIPE_TO_SERVER_PATH "/tmp/my_pipe_to_server"
#define PIPE_FROM_SERVER_PATH "/tmp/my_pipe_from_server"

#define SOCKET_PATH "/tmp/my_socket"

#define SHM_DATA_PATH "/dev/shm/my_shared_data"
#define SHM_LOCK_PATH "/dev/shm/my_shared_lock"

#define BUFFER_SIZE 64

typedef struct {
        FILE *in_stream;
        FILE *out_stream;
} PipeServer;

typedef struct {
        int fd_server;
        int fd_client;
        FILE *stream;
        struct sockaddr_un addr;
} SocketServer;

typedef struct {
        int fd_shm_data;
        int fd_shm_lock;
        volatile char *shm_data;
        volatile char *shm_lock;
} SharedServer;

void pipe_server_free(PipeServer *p);
bool pipe_server_run(void);
void socket_server_free(SocketServer *s);
bool socket_server_run(void);
void shared_server_free(SharedServer *s);
bool shared_server_run(void);

void pipe_server_free(PipeServer *p) {
    if (p) {
        // Close input stream if it was opened.
        if (p->in_stream) {
            fclose(p->in_stream);
            p->in_stream = NULL;
        }

        // Close output stream if it was opened.
        if (p->out_stream) {
            fclose(p->out_stream);
            p->out_stream = NULL;
        }

        // Remove the named pipes from the filesystem.
        unlink(PIPE_TO_SERVER_PATH);
        unlink(PIPE_FROM_SERVER_PATH);

        printf("[SERVER] Pipe Server Shutdown.\n");
    }
}

bool pipe_server_run(void) {
    PipeServer p = {0};

    // Create named pipe for input.
    mkfifo(PIPE_TO_SERVER_PATH, 0666);

    // Open input pipe for reading.
    p.in_stream = fopen(PIPE_TO_SERVER_PATH, "r");
    if (p.in_stream == NULL) {
        perror("[SERVER] Error: Opening Named Pipe in_stream.");
        pipe_server_free(&p);
        return false;
    }

    // Create named pipe for output.
    mkfifo(PIPE_FROM_SERVER_PATH, 0666);

    // Open output pipe for writing.
    p.out_stream = fopen(PIPE_FROM_SERVER_PATH, "w");
    if (p.out_stream == NULL) {
        perror("[SERVER] Error: Opening Named Pipe out_stream.");
        pipe_server_free(&p);
        return false;
    }

    int value = 0;
    char buffer[BUFFER_SIZE] = {0};

    printf("[SERVER] Pipe server running...\n");
    // While pipe is open get a line and place it in buffer.
    while (fgets(buffer, BUFFER_SIZE, p.in_stream)) {
        // convert string in buffer to int.
        value = atoi(buffer);
        if (value == -2) {
            break;
        } else {
            // Write the integer value to the output pipe.
            fprintf(p.out_stream, "%i\n", value);
            // Flush to ensure immediate delivery.
            fflush(p.out_stream);
        }
    }

    pipe_server_free(&p);
    return true;
}

void socket_server_free(SocketServer *s) {
    if (s) {
        // Close stream wrapper (also closes the client socket).
        if (s->stream != NULL) {
            fclose(s->stream);
            s->stream = NULL;
            s->fd_client = -1;
        }

        // Close the client socket.
        if (s->fd_client >= 0) {
            close(s->fd_client);
            s->fd_client = -1;
        }

        // Close the server socket.
        if (s->fd_server >= 0) {
            close(s->fd_server);
            s->fd_server = -1;
        }

        // Remove the socket from the filesystem
        unlink(SOCKET_PATH);

        // Clear the socket address structure
        memset(&s->addr, 0, sizeof(s->addr));

        printf("[SERVER] Socket Server Shutdown.\n");
    }
}

bool socket_server_run(void) {
    SocketServer s = {0};

    // Remove any existing socket file.
    unlink(SOCKET_PATH);

    // Create a Unix domain socket.
    s.fd_server = socket(AF_UNIX, SOCK_STREAM, 0);
    if (s.fd_server == -1) {
        perror("[SERVER] Error: Creating a Unix Domain Socket.");
        socket_server_free(&s);
        return false;
    }

    // Set up the socket address structure.
    memset(&s.addr, 0, sizeof(struct sockaddr_un));
    s.addr.sun_family = AF_UNIX;
    strncpy(s.addr.sun_path, SOCKET_PATH, sizeof(s.addr.sun_path) - 1);

    // Bind the socket to the file path.
    if (bind(s.fd_server, (struct sockaddr *)&s.addr,
             sizeof(struct sockaddr_un)) == -1) {
        perror("[SERVER] Error: Binding the socket to file path.");
        socket_server_free(&s);
        return false;
    }

    // Start listening for connections.
    if (listen(s.fd_server, 5) == -1) {
        perror("[SERVER] Error: Listening for connections.");
        socket_server_free(&s);
        return false;
    }

    int value = 0;
    char buffer[BUFFER_SIZE] = {0};
    bool running = true;

    printf("[SERVER] Socket server running...\n");
    while (running) {
        // Accept a new client connection on the server socket.
        s.fd_client = accept(s.fd_server, NULL, NULL);
        if (s.fd_client == -1) {
            perror("[SERVER] Error: Accepting client connection.");
            continue;
        }

        // Wrap the client socket in a stream for buffered I/O.
        s.stream = fdopen(s.fd_client, "r+");
        if (s.stream == NULL) {
            perror("[SERVER] Error: Wrapping client socket with fdopen.");
            close(s.fd_client);
            continue;
        }

        // While socket is open get a line and place it in buffer.
        while (fgets(buffer, BUFFER_SIZE, s.stream)) {
            // convert string in buffer to int.
            value = atoi(buffer);
            if (value == -2) {
                running = false;
                break;
            } else {
                // Write the integer value to the stream.
                fprintf(s.stream, "%i\n", value);
                // Flush to ensure immediate delivery.
                fflush(s.stream);
            }
        }
    }

    socket_server_free(&s);
    return true;
}

void shared_server_free(SharedServer *s) {
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

        // Remove shared memory from the filesystem.
        unlink(SHM_DATA_PATH);
        unlink(SHM_LOCK_PATH);

        printf("[SERVER] Shared Server Shutdown.\n");
    }
}

bool shared_server_run(void) {
    SharedServer s = {0};

    // Open the shared memory data file for reading and writing.
    s.fd_shm_data = open(SHM_DATA_PATH, O_RDWR);
    if (s.fd_shm_data < 0) {
        perror("[SERVER] Error: Opening shared memory file.");
        shared_server_free(&s);
        return false;
    }

    // Resize the shared memory data file to match the buffer size.
    if (ftruncate(s.fd_shm_data, BUFFER_SIZE) == -1) {
        perror("[SERVER] Error: Ftruncating shared memory data file.");
        shared_server_free(&s);
        return false;
    }

    // Open the shared memory lock file for reading and writing.
    s.fd_shm_lock = open(SHM_LOCK_PATH, O_RDWR);
    if (s.fd_shm_lock < 0) {
        perror("[SERVER] Error: Opening shared memory file.");
        shared_server_free(&s);
        return false;
    }

    // Resize the shared memory lock file to match the buffer size.
    if (ftruncate(s.fd_shm_lock, BUFFER_SIZE) == -1) {
        perror("[SERVER] Error: Ftruncating shared memory lock file.");
        shared_server_free(&s);
        return false;
    }

    // Map the shared data file into memory for read/write access
    s.shm_data = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                      s.fd_shm_data, 0);
    if (s.shm_data == MAP_FAILED) {
        perror("[SERVER] Error: Mmaping shared memory data file.");
        shared_server_free(&s);
        return false;
    }

    // Map the shared lock file into memory for read/write access
    s.shm_lock = mmap(NULL, BUFFER_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED,
                      s.fd_shm_lock, 0);
    if (s.shm_lock == MAP_FAILED) {
        perror("[SERVER] Error: Mmaping shared memory lock file.");
        shared_server_free(&s);
        return false;
    }

    // Initialize both shared memory regions to zero.
    memset((void *)s.shm_data, 0, BUFFER_SIZE);
    memset((void *)s.shm_lock, 0, BUFFER_SIZE);

    int value = 0;
    struct timespec ts = {0, 1000};

    printf("[SERVER] Shared server running...\n");
    while (true) {
        // Check the first char of the shared memory lock.
        // 0 client can write, 1 server can read/write,
        // 2 client can read, and 3 server shut down.
        if (s.shm_lock[0] == 1) {
            // Convert shared memory data to int.
            value = atoi((char *)s.shm_data);
            // Write the int back to shared memory data as a string.
            snprintf((char *)s.shm_data, BUFFER_SIZE, "%d", value);
            s.shm_lock[0] = 2;
        } else if (s.shm_lock[0] == 3) {
            break;
        }

        // Sleep briefly to reduce CPU usage.
        nanosleep(&ts, NULL);
    }

    shared_server_free(&s);

    return true;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Error: %s requires an argument.\n", argv[0]);
        return EXIT_FAILURE;
    }

    if (strcmp(argv[1], "--pipe") == 0) {
        if (!pipe_server_run()) {
            return EXIT_FAILURE;
        }
    } else if (strcmp(argv[1], "--socket") == 0) {
        if (!socket_server_run()) {
            return EXIT_FAILURE;
        }
    } else if (strcmp(argv[1], "--shared") == 0) {
        if (!shared_server_run()) {
            return EXIT_FAILURE;
        }
    } else {
        fprintf(stderr, "Error: Argument %s is not valid.\n", argv[1]);
    }

    return EXIT_SUCCESS;
}
