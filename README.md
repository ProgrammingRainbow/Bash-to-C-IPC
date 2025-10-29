# Bash-to-C-IPC
Bash to C Inter-Process Communication. Unix Named Pipes, Standard in and out, Unix Sockets, direct Shared Memory, and Shared Memory using client.

There is 5 options. A Unix Named pipe seems to be the best option. There is also an option to communicate to the server using the servers standard in and out(not recommened). A Unix socket. Shared memory mapped directly from bash and the server. A small client that spins up and connects to the server using shared memory. This is about 149 times slower than the fastest method. This is Copilots recomends fastest possible method.

The test sends data to the server one way without reply. Then it sends another data that does require a reply and checks this. It loops this 1 millions times.

# MacOS & Zsh
The scripts run by default as bash. but if called using zsh they will run in that mode. On MacOS the shared and client will not work since they use shared memory.

# Build
```
make release
```
# Speed tests
All tests were run from the fish user shell but they are exectured as bash not fish. Times were taken using time `time ./run-test.sh --pipe`. Tests were run on an AMD AI 9 HX 370 plugged in and set to power save mode.
## Unix Named Pipe: 11.18 seconds
```
❯ time ./run-test.sh --pipe
Running in Bash
[SERVER] Starting Pipe Server.
[SERVER] Listening on pipe.
Total received: 1000000 of 1000000
[SERVER] Pipe Server Shutdown.

________________________________________________________
Executed in   11.18 secs    fish           external
   usr time    9.69 secs  372.00 micros    9.69 secs
   sys time    3.43 secs  247.00 micros    3.43 secs
```
## Standard In / Out: 11.25 seconds
```
❯ time ./run-test.sh --stdinout
Running in Bash
[SERVER] Starting Stdinout Server.
[SERVER] Listening on standard in.
Total received: 1000000 of 1000000
[SERVER] Stdinout Server Shutdown.

________________________________________________________
Executed in   11.25 secs    fish           external
   usr time    9.25 secs    0.00 micros    9.25 secs
   sys time    1.95 secs  800.00 micros    1.95 secs
```
## Unix Socket: 17.88 seconds
```
❯ time ./run-test.sh --socket
Running in Bash
[SERVER] Starting Socket Server.
[SERVER] Waiting for connection.
[SERVER] Listening on socket.
Total received: 1000000 of 1000000
[SERVER] Socket Server Shutdown.

________________________________________________________
Executed in   17.88 secs    fish           external
   usr time   11.80 secs  212.00 micros   11.80 secs
   sys time    5.86 secs  468.00 micros    5.86 secs
```
## Direct Shared Memory: 106.55 seconds
```
❯ time ./run-test.sh --shared
Running in Bash
[SERVER] Starting Shared Server.
[SERVER] Waiting for shared data.
Total received: 1000000 of 1000000
[SERVER] Shared Server Shutdown.

________________________________________________________
Executed in  106.53 secs    fish           external
   usr time   87.98 secs    0.00 micros   87.98 secs
   sys time   20.20 secs  974.00 micros   20.20 secs
```
## Shared Memory using Client: 1663.8 seconds, 27.73 minutes (Copilots recommended fastest possible method from bash to c, 149 times slower)
```
❯ time ./run-test.sh --client
Running in Bash
[SERVER] Starting Shared Server.
[SERVER] Waiting for shared data.
Total received: 1000000 of 1000000
[SERVER] Shared Server Shutdown.

________________________________________________________
Executed in   27.73 mins    fish           external
   usr time   12.22 mins  489.00 micros   12.22 mins
   sys time   17.04 mins  318.00 micros   17.04 mins
```

