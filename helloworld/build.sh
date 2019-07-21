#!/bin/bash

docker build --pull -t fred78290/helloworld:v1.0.0 .
docker push fred78290/helloworld:v1.0.0