#!/bin/bash

curl -X POST http://localhost:8080/echo/_/session_1/xhr
curl -X POST http://localhost:8080/echo/_/session_1/xhr_send -d 'msg 1'
curl -X POST http://localhost:8080/echo/_/session_1/xhr_send -d 'msg 2'
curl -X POST http://localhost:8080/echo/_/session_1/xhr_send -d 'msg 3'
curl -X POST http://localhost:8080/echo/_/session_1/xhr_send -d 'msg 4'
curl -X POST http://localhost:8080/echo/_/session_1/xhr_send -d 'msg 5'
curl -X POST http://localhost:8080/echo/_/session_1/xhr
