#!/bin/bash

server1=localhost:2020
server2=localhost:2021

result=`curl --request GET --silent --output /dev/null --write-out "%{http_code}" $server1/`

if [ $result == 200 ]
then
  echo "Success"
else
  echo "Failure"
fi

case $result in
  200)
    echo "Success"
    ;;
  *)
    echo "Failure"
    ;;
esac
