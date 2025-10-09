# Bash-to-C-IPC
Bash to C Inter-Process Communication. Unix Named Pipes, Unix Sockets and Shared Memory.

# Build
```
make release
```
# Run
There is 4 options. A small client app that spins up and connects to the server using shared memory. This is about 100 times slower then the fastest method. You can also let bash connect directly to shared Memory to the server. There is also a socket and pipe version directly from bash to the c server. The Test will send the current index to the C server. It will then send it back. The bash script will then check that number and incement it's counter. If it's wrong it will fail. On my machine pipe takes 7 seconds, sockets takes 14 seconds, shared memory takes 53 seconds and the client app takes 915 secons. Thats 15 minutes for 1 million round trips to bash. ChatGPT recomends this as the fastest possible method.
```
./run-test.sh --pipe
```
```
./run-test.sh --socket
```
```
./run-test.sh --shared
```
```
./run-test.sh --client
```
