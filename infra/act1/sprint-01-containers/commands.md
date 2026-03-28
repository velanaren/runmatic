# Commands Used
### What's currently running?
  docker ps

### Full metadata — everything Docker knows about this container
  docker inspect redis-test

### Stop it (back in the original tab you'll see Redis shut down)
  docker stop redis-test

### Is it gone?
  docker ps

### Is it really gone?
  docker ps -a

### Start it again (detached this time — -d means background)
  docker run -d --name redis-test2 -p 6379:6379 redis:7-alpine

### Confirm it's running
  docker ps

### Read its logs without being attached
  docker logs redis-test2

