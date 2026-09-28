# Harbor Goods catalog API: the first working Dockerfile.
#
# Exercise 1: pin the base image by digest. Find it with
#   docker buildx imagetools inspect python:3.14-slim
# Exercise 2: copy only the two files the app needs, not the whole build context.
# Exercise 3: run as a numeric, unprivileged user (for example 10001:10001).
# Exercise 4: add a HEALTHCHECK that calls /health (there is no curl in the image: use python).
# Exercise 5: use the exec form of CMD so that python receives SIGTERM from ECS.
# Exercise 6: remove pip from the image; the app needs no package manager at run time.
# Also set PYTHONDONTWRITEBYTECODE=1: on ECS the root filesystem will be read-only.
FROM python:3.14-slim

WORKDIR /app
COPY . .

EXPOSE 8080

CMD python app/server.py
