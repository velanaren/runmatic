# Sprint 2 - Images and Layers 
## Image 

An image is a read-only snapshot of a filesystem — plus metadata that tells Docker what command to run when a container starts.

Image (recipe):
┌─────────────────────────────────┐
│  Filesystem snapshot            │  ← exact files, exact versions
│  Environment variables          │  ← runtime configuration
│  Metadata: what command to run  │  ← e.g. "start uvicorn"
│  READ ONLY. Never changes.      │
└─────────────────────────────────┘

Container (meal cooked from recipe):
┌─────────────────────────────────┐
│  Running instance of the image  │
│  Has its own writable layer     │  ← can write files, generate logs
│  Lives and dies independently   │
└─────────────────────────────────┘

## Layers

Image is not one big file it is a stack of independent Layers. Each Layer is one instruction that changed the file system.

Layer 4: COPY app code          ← your application
    ▲
Layer 3: RUN pip install        ← your dependencies  
    ▲
Layer 2: RUN apt-get install    ← system packages
    ▲
Layer 1: Ubuntu 22.04 base      ← the OS filesystem



docker pull is used to pull the image

```shell
 docker pull python:3.11-slim
```


when we pull the same image again, we get below message . Image is up to date for python:3.11-slim and it displays a digest value indicating there is no change in the image and the digest value of first pulled image and now is the same 

To list the images downloaded use below command 

```shell
docker image ls 
```

To see how each layer is stacked in the image, use below command 

```shell
docker image history python:3.11-slim
```

To see the metadata of the image 

```shell
docker image inspect python:3.11-slim
```

The rootFS section in docker above command will give the number of layers

In this case, image history gave 10 layers and image inspect command gave 4 layers for the same image 
Reason - 
docker image history shows every build instruction ,  including zero-size metadata steps like ENV, CMD, LABEL. These are   recorded but write nothing to disk.
docker image inspect RootFS shows only layers that actually changed the filesystem. These are the real layers. 4 layers  = 4 times something was written.

> [!NOTE] Challenge 
> You have python:3.11-slim on disk. Run this:
> docker pull python:3.12-slim
> Watch the output carefully as it pulls. Then run:
> docker image ls
  docker image inspect python:3.12-slim
  Two questions:
  1.During the pull — which lines said "Already exists"? Which downloaded fresh?  2. docker image ls shows a size for each image. Add them up. Now run docker system df — what does the actual disk usage   say? Explain the difference.
  

When i run docker pull python:3.12-slim, got below output

3.12-slim: Pulling from library/python
f4badedbec24: Already exists 
e154f12a68d4: Pull complete 
41a4e6de4142: Pull complete 
bf2133636eec: Pull complete 

Docker pulls images bottom up, the very first layer is the base layer - which is debian OS
which is shown as already exists 

 debian.sh --arch 'arm64' out/ 'trixie' '@1773619200'
 
 This is the same one as in python:3.11
 
 A common command between inspect of python:3.11 and python3.12 indicate there is a common layer 

```comm -12 <(docker image inspect python:3.11-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort) \
         <(docker image inspect python:3.12-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort)
```

sha256:dbd35b2200dce25964b5371e8221a0b6c8638a6d86d76e2b1795b7584c5d4428


Docker system df size is smaller the sum total of size in image ls 

Reason - Let us take the same python:3.11 and python:3.12 as example and i run docker system df -v command 

REPOSITORY                                       TAG                                                                           IMAGE ID       CREATED         SIZE      SHARED SIZE   UNIQUE SIZE   CONTAINERS
python                                           3.11-slim                                                                     0725b147cc5e   12 days ago     150MB     100.5MB       49.17MB       0
python                                           3.12-slim                                                                     657d15078a33   12 days ago     144MB     100.5MB       43.89MB       0

Image size is almost identical, but the shared size is 100.5 MB ( THE BASE LAYER - debian os which was not downloaded when we pulled 3.12 as it is already available from 3.11)

so total image size is 294 MB
Shared size is 100.5 mb + unique size ( 49.17 mB + 43.89 MB) - Ssytem space occupied is 193.56

that is why docker system df size is smaller than sum total of size in image ls

Image A                           Image B 
┌─────────────────────┐          ┌─────────────────────┐
│ Layer 4: api code   │          │ Layer 4: worker code │
├─────────────────────┤          ├─────────────────────┤
│ Layer 3: pip deps   │          │ Layer 3: pip deps    │
├─────────────────────┤          ├─────────────────────┤
│ Layer 2: python3.11 │◄─────────► Layer 2: python3.11 │
├─────────────────────┤  SHARED  ├─────────────────────┤
│ Layer 1: Ubuntu     │◄─────────► Layer 1: Ubuntu      │
└─────────────────────┘  ON DISK └─────────────────────┘ 

 
> [!NOTE] BONUS CHALLENGE 
>  A Dockerfile has 8 instructions. A developer changes
  instruction 3 and rebuilds. The build takes 9 minutes —
  same as a clean build with no cache at all.
  They complain: "Docker caching is broken."
  They're wrong. What's actually happening, and what's
  the fix? No commands needed — this is pure reasoning.


It comes from wrong assumption that caching is automatic. It is not the case, If layer 3 is changed, docker doesn't know whether other layers 4,5,6,7,8 would produce same result, so it rebuilds them all to be safe.The instructions should be provided in such a way that, the file that changes least frequently should be copied first, the file that changes most frequently should be copied last. Consider the developer is changing instruction 3 - which could be the app code which changes frequently then it should copied last.

Sample Example below ( if we are changing the app code)

Change a layer → that layer rebuilds
                 → every layer AFTER it rebuilds too
                 → every layer BEFORE it stays cached

Incorrect order 
Layer 1 - python - cached 
layer 2 - copy . /app - Rebuilds 
Layer 3 - pip install - Rebuilds 

Correct order ( files that change most frequenlty should be copied last )
Layer 1 - python - cached
layer 2 - copy requirements - cached
Layer 3 - pip install - cached 
Layer 4 - copy ./app - rebuilds 



