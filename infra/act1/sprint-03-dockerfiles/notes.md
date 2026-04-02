#  Sprint 3 - Docker Files

### Docker Files

A docker file is a sequence of instructions that docker executes to build an image one layer at a time. we have provisioned servers manually before - Login, install python, install packages, copy app code, configure the start command. A docker file is exact process, writted down as code. It runs identically on any machine

Manual server setup:          Dockerfile equivalent:
----------------------        ----------------------
Start with Ubuntu             →   FROM ubuntu:22.04
Install Python                    →   RUN apt-get install python3
Copy requirements.txt     →   COPY requirements.txt .
pip install                           →   RUN pip install -r requirements.txt
Copy app code                  →   COPY . /app
Start the app                     →   CMD ["uvicorn", "main:app"]

CMD runs only when the container is started, other commands execute during BUILD time

we need to build an image for runmatic-api, the required code are present in app/api folder
It has 2 folders - app, migrations 2 files - alembic.ini, requirements.txt all of this has to be copied to dockerfile

FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
COPY alembic.ini .
RUN pip install --no-cache-dir  -r requirements.txt
COPY migrations ./migrations
EXPOSE 8000
copy app ./app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

| command               | Details                                                      |
|-----------------------|--------------------------------------------------------------|
| FROM python:3.11-slim | Every image starts with another image, here we are already using downloaded python:3.11-slim |
| WORKDIR /app          | Sets the working directory for everything that follows, without this files land in / ( root) |
| COPY                  | Copy the files/folders to the destination in image           |
| RUN requirements.txt  | Runs this during build time, installed packages frozen in a layer |
| EXPOSE 8000           | It is documentation purpose only, it just says container listens in port 8000 |
| CMD                   | Command that runs when the container starts                  |

Docker build and run command 

docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
docker run -d port 8000:8000 —name api-test runmatic-api-v1

The build context is app/api - this is where all the files required are available 

### Layer caching Strategy

The order in which the commands are written are crucial for build. 
Most stable content → TOP of Dockerfile
Most changing content → BOTTOM of Dockerfile

Consider the previosu docker file, code is the one that may change often so it is in the bottom of the docker file
Added a comment to end of main.py, ran the build command.Layer 1,2,3,4,5,6 are cached The app copy alone was rebuilt

time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
[+] Building 0.1s (12/12) FINISHED docker:desktop-linux => [internal] load build definition from Dockerfile.api 0.0s => => transferring dockerfile: 300B 0.0s => [internal] load metadata for docker.io/library/python:3.11-slim 0.0s => [internal] load .dockerignore 0.0s => => transferring context: 2B 0.0s => [1/7] FROM docker.io/library/python:3.11-slim 0.0s => [internal] load build context 0.0s => => transferring context: 8.13kB 0.0s => CACHED [2/7] WORKDIR /app 0.0s => CACHED [3/7] COPY requirements.txt . 0.0s => CACHED [4/7] COPY alembic.ini . 0.0s => CACHED [5/7] RUN pip install --no-cache-dir -r requirements.txt 0.0s => CACHED [6/7] COPY migrations ./migrations 0.0s => [7/7] COPY app ./app 0.0s => exporting to image 0.0s => => exporting layers 0.0s => => writing image sha256:91926e5eeb1e1fd760fc0fa71cc4277f09615da07a7f593319705b32599d25af 0.0s => => naming to docker.io/library/runmatic-api-v1 0.0s

Again added a comment to main.py. This time moved the copy app command after workdir all layers below it was rebuild, total time takwen - 29.5s compared to 0s last time pip install took the most time

everytime there is code change all layers from copy app will be rebuild and it will take time.

time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
[+] Building 29.5s (12/12) FINISHED docker:desktop-linux => [internal] load build definition from Dockerfile.api 0.0s => => transferring dockerfile: 300B 0.0s => WARN: ConsistentInstructionCasing: Command 'copy' should match the case of the command majority (uppercase) (lin 0.0s => [internal] load metadata for docker.io/library/python:3.11-slim 0.0s => [internal] load .dockerignore 0.0s => => transferring context: 2B 0.0s => [1/7] FROM docker.io/library/python:3.11-slim 0.0s => CACHED [2/7] WORKDIR /app 0.0s => [internal] load build context 0.0s => => transferring context: 8.14kB 0.0s => [3/7] COPY app ./app 0.0s => [4/7] COPY requirements.txt . 0.0s => [5/7] COPY alembic.ini . 0.0s => [6/7] RUN pip install --no-cache-dir -r requirements.txt 28.8s => [7/7] COPY migrations ./migrations 0.0s => exporting to image 0.6s => => exporting layers 0.5s => => writing image sha256:a6bd16ad663cedb37e132f117009ec6cbc2f9794c56d7034c17626314fa43cd7 0.0s => => naming to docker.io/library/runmatic-api-v1 0.0s

### Exec Form and Shell Form in command

There are two ways in which CMD can be formatted - Exec form and Shell form 

Shell form 
CMD uvicorn main:app --host 0.0.0.0
Exec firm 
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]

They look almost identical. The difference is what Docker actually runs. Shell form — what happens under the hood: 
Docker runs: 
/bin/sh -c "uvicorn main:app --host 0.0.0.0" Process tree inside container: 
PID 1: /bin/sh ← shell is PID 1 
PID 2: uvicorn ← your app is PID 2 

 Exec form — what happens under the hood: 
Docker runs: uvicorn main:app --host 0.0.0.0 
Process tree inside container: 
PID 1: uvicorn ← your app IS PID 1 

Why PID 1 matters: When you run docker stop, Docker sends **SIGTERM** to PID 1 — "please shut down gracefully." 
Shell form: 
SIGTERM → /bin/sh 
(PID 1) /bin/sh does NOT forward signals to children 
uvicorn (PID 2) never receives SIGTERM 
uvicorn never shuts down gracefully 
Docker waits 10 seconds → sends SIGKILL → force kills everything

 Exec form: 
SIGTERM → uvicorn (PID 1) directly 
uvicorn receives signal → shuts down gracefully Connections close cleanly, no data corruption 
The real-world consequence: 
Shell form = every docker stop is a force kill after 10 seconds 
database connections dropped mid-transaction 
requests cut off mid-response 
logs not flushed
 Exec form = clean shutdown 
connections drain properly 
data integrity preserved

### Dockerignore file

COPY . /app will copy everything in a directory including things you never want to copy in an image
.dockerfile is like .gitignore that is used to exclude sensirtive information that need not be copied for the docker image, anything included inside .dockerignore - will be never part of the image









