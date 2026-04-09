#!/bin/bash
# Sprint 05 — Volumes & Persistence
# Goal: Prove that data survives container removal when stored in a named volume
# Key question: What's the difference between container filesystem and volume storage?

# === Phase 1: Prove the problem — container filesystem is ephemeral ===

# why: Run postgres WITHOUT a volume to prove data is lost on container removal
docker run -d --name postgres-test \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  postgres:15-alpine
# what I saw: Container started successfully

# why: Insert test data
docker exec -it postgres-test psql -U postgres -d runmatic -c \
  "CREATE TABLE test_data (id SERIAL PRIMARY KEY, value TEXT); \
   INSERT INTO test_data (value) VALUES ('this data will disappear');"
# what I saw: CREATE TABLE, INSERT 0 1

# why: Verify data exists
docker exec -it postgres-test psql -U postgres -d runmatic -c \
  "SELECT * FROM test_data;"
# what I saw:
#  id |          value
# ----+--------------------------
#   1 | this data will disappear
# (1 row)

# why: Destroy container and create a fresh one (NO volume attached)
docker stop postgres-test && docker rm postgres-test

docker run -d --name postgres-test \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  postgres:15-alpine

# why: Check if data survived
docker exec -it postgres-test psql -U postgres -d runmatic -c \
  "SELECT * FROM test_data;"
# what I saw: ERROR:  relation "test_data" does not exist
# KEY INSIGHT: Data is GONE. Container filesystem is ephemeral by design.

# === Phase 2: Fix the problem with a named volume ===

# why: Create a named volume managed by Docker
docker volume create postgres-data
# what I saw: postgres-data

# why: Run postgres WITH the named volume mounted at /var/lib/postgresql/data
docker run -d --name postgres-test \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15-alpine
# what I saw: Container started

# why: Insert test data
docker exec -it postgres-test psql -U postgres -d runmatic -c \
  "CREATE TABLE test_data (id SERIAL PRIMARY KEY, value TEXT); \
   INSERT INTO test_data (value) VALUES ('this data will disappear');"

# why: Verify data exists
docker exec -it postgres-test psql -U postgres -d runmatic -c \
  "SELECT * FROM test_data;"
# what I saw: 1 row with "this data will disappear"

# why: List all volumes
docker volume ls
# what I saw: postgres-data in the list

# why: Inspect volume to see where Docker stores it on the host
docker volume inspect postgres-data
# what I saw: Mountpoint: /var/lib/docker/volumes/postgres-data/_data (inside Docker Desktop VM on Mac)

# why: Stop the container
docker stop postgres-test

# why: Create a DIFFERENT container (postgres-test-1) with the SAME volume
docker run -d --name postgres-test-1 \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15-alpine
# what I saw: New container started

# why: Verify data STILL EXISTS in the new container
docker exec -it postgres-test-1 psql -U postgres -d runmatic -c \
  "SELECT * FROM test_data;"
# what I saw: Same row, data persisted!
# KEY INSIGHT: The volume is independent of the container. Data survives.

# === Phase 3: Anonymous volumes — the hidden danger ===

# why: Run postgres WITHOUT specifying a volume name
docker run -d --name postgres-no-volume \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  postgres:15-alpine

# why: Run postgres WITH a named volume
docker run -d --name postgres-with-volume \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:15-alpine

# why: Inspect mounts for the "no volume" container
docker inspect postgres-no-volume | grep -A 10 Mounts
# what I saw: Docker created an ANONYMOUS volume with a hex hash name
# "Name": "571d0b23ed8c475eafecfb3cf67b52ab521b00e5e9c2a291218bd7ba22556f4d"
# KEY INSIGHT: Postgres Dockerfile has VOLUME /var/lib/postgresql/data
# If you don't name it, Docker auto-creates an anonymous volume

# why: Inspect mounts for the "with volume" container
docker inspect postgres-with-volume | grep -A 10 Mounts
# what I saw:
# "Name": "postgres-data" (our named volume)

# why: List volumes to see the anonymous one
docker volume ls | grep 571d0b23ed8c475eafecfb3cf67b52ab521b00e5e9c2a291218bd7ba22556f4d
# what I saw: The anonymous volume exists and survives even after docker rm

# why: Test if we can reuse the anonymous volume by its hash name
docker run -d --name postgres-with-volume \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  -v 571d0b23ed8c475eafecfb3cf67b52ab521b00e5e9c2a291218bd7ba22556f4d:/var/lib/postgresql/data \
  postgres:15-alpine
# what I saw: It works! You CAN reuse anonymous volumes if you know their hash.
# But: who remembers a 64-character hex hash? This is why they're orphans.

# why: Clean up orphaned anonymous volumes
docker volume ls
docker volume prune
# what I saw: Removes all volumes not attached to any container
# DANGER: If you have important data in an anonymous volume, prune will delete it

# === Phase 4: Backup and restore challenge ===

# why: Create a backup volume
docker volume create runmatic-postgres-backup

# why: Backup postgres-data volume contents as a tar.gz file
docker run --rm \
  -v postgres-data:/source:ro \
  -v runmatic-postgres-backup:/backup \
  alpine tar czf /backup/postgres-backup.tar.gz -C /source .
# what I saw: Tar archive created in the backup volume
# KEY INSIGHT: Used Alpine as a tool container. :ro = read-only on source.

# why: Verify backup was created
docker volume inspect runmatic-postgres-backup

# why: Simulate disaster — delete the original volume
docker volume rm postgres-data
# (In the challenge, this was accidental. All data "gone".)

# why: Restore from backup into a new volume
docker run --rm \
  -v runmatic-postgres-backup:/backup:ro \
  -v postgres-restored:/target \
  alpine tar xzf /backup/postgres-backup.tar.gz -C /target
# what I saw: Data extracted into postgres-restored volume

# why: Start postgres with the restored volume
docker run -d --name postgres-with-volume \
  -e POSTGRES_PASSWORD=testpass \
  -e POSTGRES_DB=runmatic \
  -v postgres-restored:/var/lib/postgresql/data \
  postgres:15-alpine

# why: Verify all data was restored
docker exec -it postgres-with-volume psql -U postgres -d runmatic -c \
  "SELECT * FROM test_data;"
# what I saw: Original row still there. Backup/restore successful!

# === Key Takeaways ===
# 1. Container filesystem is ephemeral — data is lost on container removal by design
# 2. Named volumes persist independently of container lifecycle
# 3. Postgres image auto-creates anonymous volumes if you don't specify -v
# 4. Anonymous volumes are orphans — they survive docker rm but nobody knows what they're for
# 5. docker volume prune deletes anonymous volumes — dangerous if they contain live data
# 6. Backup/restore pattern: Alpine tool container + tar + :ro flag on source
# 7. In production: always name your volumes explicitly, never rely on anonymous volumes
