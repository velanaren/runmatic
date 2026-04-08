#!/bin/bash
# Sprint 02 — Images & Layers
# Goal: Understand what an image is, how layers work, and why they matter for build speed
# Key question: Why does pulling the same image twice take no time?

# === Phase 1: Pulling images and observing layers ===

# why: Pull the Python image that Runmatic's API is built on
# what I expected: Single download
# what actually happened: Multiple lines downloading — each line is a layer
docker pull python:3.11-slim

# why: Pull the exact same image again immediately
# what I saw: "Image is up to date" — no download, instant response
# KEY INSIGHT: Docker checks digest (SHA256), knows it already has this exact image
docker pull python:3.11-slim

# === Phase 2: Inspecting image structure ===

# why: List all images on disk
docker image ls

# why: Look inside the layer stack of the Redis image (already have from Sprint 01)
# what I saw: Shows every build instruction, including zero-size metadata steps (ENV, CMD, LABEL)
docker image history redis:7-alpine

# why: Look at Python's layer stack
# what I saw: 10 lines in history output
docker image history python:3.11-slim

# why: Full metadata — RootFS section shows every layer's SHA256
# what I saw: Only 4 layers in RootFS.Layers
docker image inspect python:3.11-slim

# KEY INSIGHT:
# docker image history → 10 layers (includes zero-size metadata like ENV, CMD, LABEL)
# docker image inspect RootFS → 4 layers (only layers that actually wrote to disk)
# The difference: history shows build instructions, inspect shows real filesystem layers

# === Phase 3: Challenge — Shared layers across images ===

# Problem: You have python:3.11-slim on disk. Now pull python:3.12-slim.
# Question 1: Which layers say "Already exists"? Which download fresh?
# Question 2: Why does docker system df show less disk usage than sum of image sizes?

# why: Pull a second Python image to observe layer sharing
docker pull python:3.12-slim
# what I saw during pull:
#   f4badedbec24: Already exists  ← base layer (Debian OS)
#   e154f12a68d4: Pull complete   ← Python 3.12 specific
#   41a4e6de4142: Pull complete
#   bf2133636eec: Pull complete

# why: Find the common layer between 3.11 and 3.12
comm -12 <(docker image inspect python:3.11-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort) \
         <(docker image inspect python:3.12-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort)
# Output: sha256:dbd35b2200dce25964b5371e8221a0b6c8638a6d86d76e2b1795b7584c5d4428
# This is the shared Debian base layer

# why: Check actual disk usage vs reported image sizes
docker image ls | grep python
# Shows: python 3.11-slim = 150MB, python 3.12-slim = 144MB
# Sum = 294MB

docker system df -v | grep python
# Shows:
#   python:3.11-slim → Size: 150MB, Shared: 100.5MB, Unique: 49.17MB
#   python:3.12-slim → Size: 144MB, Shared: 100.5MB, Unique: 43.89MB
# Actual disk usage: 100.5MB (shared) + 49.17MB + 43.89MB = 193.56MB

# KEY INSIGHT:
# Images share layers on disk. The Debian base (100.5MB) is stored once.
# Only the unique layers (Python 3.11 vs 3.12 differences) take extra space.
# This is why pulling python:3.12-slim was fast — 1 layer "Already exists"

# Visual representation:
# Image A (3.11)               Image B (3.12)
# ┌─────────────────┐          ┌─────────────────┐
# │ Layer 3: py3.11 │          │ Layer 3: py3.12 │
# ├─────────────────┤          ├─────────────────┤
# │ Layer 2: ...    │          │ Layer 2: ...    │
# ├─────────────────┤          ├─────────────────┤
# │ Layer 1: Debian │◄─────────► Layer 1: Debian │
# └─────────────────┘  SHARED  └─────────────────┘
#                      ON DISK

# === Phase 4: Understanding disk usage ===

# why: See total Docker disk usage summary
docker system df

# why: See detailed breakdown including shared layers
docker system df -v

# KEY TAKEAWAY:
# Layers are content-addressed (SHA256). If two images have identical layers,
# Docker stores them once. This is why:
# 1. Pulling related images (python:3.11 → python:3.12) is fast
# 2. Disk usage is far less than sum of image sizes
# 3. Building multiple images from same base (e.g., api + worker both FROM python:3.11)
#    doesn't duplicate the base layer
