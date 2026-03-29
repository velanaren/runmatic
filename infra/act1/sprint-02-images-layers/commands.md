# Sprint 2 - commands 

Pull the Python image that Runmatic's API is built on
Watch the output carefully — each line is a layer downloading
  docker pull python:3.11-slim

Pull the exact same image again immediately
  docker pull python:3.11-slim

List all images — note Python is now there
  docker image ls

Look inside the layer stack of the Redis image you already have
  docker image history redis:7-alpine

Now look at Python's layer stack
  docker image history python:3.11-slim

Full metadata — RootFS section shows every layer's SHA256
  docker image inspect python:3.11-slim
