# Sprint - 1 - Containers and Docker Mental Model

### Docker 3 Layer Architecture 

YOU
 │  type commands
 ▼
┌─────────────────┐
│   Docker CLI    │  ← the waiter. Takes your order. Does no cooking.
│   (docker)      │     Translates commands into API calls.
└────────┬────────┘
         │  API call over unix socket
         ▼
┌─────────────────┐
│  Docker Daemon  │  ← the kitchen. Does ALL the real work.
│  (dockerd)      │     Pulls images, creates containers,
│                 │     manages networks, volumes, everything.
└────────┬────────┘
         │  pulls from
         ▼
┌─────────────────┐
│   Docker Hub    │  ← the supplier. Stores images.
│  (registry)     │     Public. Anyone can push or pull.
└─────────────────┘

What happens when i run the below docker command 

```shell
docker run --name redis-test -p 6379:6379 redis:7-alpine
```

1. Pull - Docker will check locally for image redisL7-alpine, it is not available. Fetches from the docker hub
2. Create - Docker builds a container from the image
3. Start - Redis process started inside it listening on port 6379

Note : After running the command, the prompt is not retuned back. The terminal is blocked because we are attached to the container's stdout. This is foreground mode. To run it in background mode and retrun the prompt once it is executed, we need to run it with -d option 


### Container Life Cycle 

docker run
    │
    ▼
┌─────────┐    docker stop     ┌─────────┐    docker rm    ┌─────────┐
│ RUNNING │ ───────────────→  │ STOPPED │ ─────────────→  │ REMOVED │
└─────────┘                   └─────────┘                  └─────────┘
    ▲                              │
    └──────────────────────────────┘
           docker start

Identify the current running containers


```shell
docker ps
```

we will stop the container redis-test that we created earlier 

```shell
docker stop redis-test 
```

Rerun docker ps command to check if the container is stopped, docker ps command will not show redis-test. The container is stopped here, it still exists and it is not deleted. To see all the existing containers including containers that are not running, run below command 

```shell
docker ps -a
```

we will start a new container now with the same image 

```shell
docker run -d --name redis-test2 -p 6379:6379 redis:7-alpine
```

Docker inspect command gives the full metadata of the container. Network settings includes the internal IP Address of the container. 

Docker logs provides logs of the container 

```shell
docker inspect redis-test2
```

```shell
docker logs redis-test2
```

Remove the container redis-test, we created initially. When a container is removed, all its contents are also removed, both docker ps and docker ps -a will not show the container details. note that this deletes only the container and not the image 

```shell
docker rm redis test
```

### Port Mapping 

The -p command in the docker run maps the host machine port to docker port ( -p  6379:6379 ), without this mapping though the container is running, it will not be reachable from host machine as they run in isolation 

Formatt is -p host:container 

docker inspect - network settings will give the container IP Address, suppose that IP is 172.17.0.2 ,  that's the container's address inside the Docker network. Your Mac cannot reach it directly. The only reason localhost:6379 works is because of -p 6379:6379, which punches a hole:  host port 6379 maps to→ container port 6379. Remove that flag and the container is completely unreachable from your machine  even though it's running fine.

WITHOUT -p:
┌─────────────────────────────────────┐
│  Your Mac                           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Container                  │    │
│  │  redis listening on :6379 ✅│    │
│  │  (nobody outside can reach) │    │
│  └─────────────────────────────┘    │
│                                     │
│  curl localhost:6379 → ❌ refused   │
└─────────────────────────────────────┘

WITH -p 8000:80:
┌─────────────────────────────────────┐
│  Your Mac                           │
│                                     │
│  :6379 ──────────────────────┐      │
│                              ▼      │
│  ┌─────────────────────────────┐    │
│  │  Container                  │    │
│  │  redis listening on :6379 ✅│    │
│  └─────────────────────────────┘    │
│                                     │
│  curl localhost:6379 → ✅ works     │
└─────────────────────────────────────┘



### Break-Fix scenario 


> [!NOTE] Break fix scenario
> A colleague hands you this command and says "Redis is running but I can't connect to it":
  ▎ docker run -d --name redis-broken redis:7-alpine
docker ps shows it's running. But redis-cli -h localhost -p 6379 ping returns an error. Diagnose it. Explain exactly what's wrong and why. Then fix it with a new docker run command.

Diagnosis :

Error : Could not connect to Redis at localhost:6379: Connection refused                                                   
1) docker ps - in the output,  ports indicate there is no mapping, it shows only the container port 6379/tcp               
2) docker inspect - port bindings are empty                                                                                
3) docker logs indicate the container is listening in port 6379                                                             
we are getting this error because host port are not mapped to container port. This is a characteristic feature of a container. It has isolated network and process. so we need to map the port so we can reach from local host .

Fix:

```shell
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine                                                
```


1. output received for redis-cli -h localhost -p 6379 ping command - PONG                                  
2. docker ps - 0.0.0.0:6379->6379/tcp, port is mapped
3. docker inspect - port bindings present - "PortBindings": {                                                                 
                "6379/tcp": [                                                                                              
                    {                                                                                                      
                        "HostIp": "",                                                                                      
                        "HostPort": "6379"                                                                                 
                    }                                                                                                      
                ]      
4. docker logs - container is helathy ready to accept connections  
  

> [!NOTE] BONUS Challenge
>   You stop redis-fixed and then run:
   docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine
  Docker throws an error immediately. The container never starts. redis-fixed isn't running — docker ps confirms it.   So why is it failing?

Diagnosis and Fix 

1. it is failing because there is already a container named redis-fixed                                                    
2. redis-fixed was stopped and not deleted, ps -a says the container exited, it is not active but still exists             
3. docker inspect redis-fixed says teh status is exited and dead is false, it also has an unique id                        
4. docker run creates a new container, rather than start an existing one, so docker needs unique name to start a new container  

what is the background process -                                                                                           
when i run docker run command with already existing continer name, the docker engine receives the request, it goes through its ledger to see if the container name exists, if it exists it will throw an error, if the container is deleted and then docker run command is ran with same container name it will create a new container but when it is already existing it will not create 
  



