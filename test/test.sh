#!/bin/bash

function call {
  local output=`curl --request GET --silent --write-out "%{http_code}\n" $1`
  result=`echo -e "$output" | tail -n 1`
  body=`echo -e "$output" | head -n -1`
}

server1=localhost:2020
server2=localhost:2021

call $server1/

if [ $result == 200 ]
then
  echo "Success"
  echo -e "$body"
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
