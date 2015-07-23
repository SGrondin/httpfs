#!/bin/bash

function call {
  local output=`curl --request $1 --silent --write-out "\n%{http_code}\n" $2`
  result=`echo -e "$output" | tail -n 1`
  body=`echo -e "$output" | head -n -1`
  body_line_count=`echo -e "$body" | wc --line`
}

# Recreate the environment
rm -rf sandbox*
rm -f server*.log
mkdir sandbox1
mkdir sandbox2

# Start the servers
server1="127.0.0.1:2020"
server2="127.0.0.1:2021"
pushd sandbox1 && ../../httpfs -p 2020 $server2 > ../out1.log &
pushd sandbox2 && ../../httpfs -p 2021 $server1 > ../out2.log &

sleep 1

echo "Check servers are initially empty"

cmd="call GET $server1/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 2 ];
then
  echo $cmd
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call GET $server2/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 2 ];
then
  echo $cmd
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

echo "Check creation of file works"

cmd="call POST $server1/foo"
eval $cmd
if [ "$result" -ne 200 ];
then
  echo "$cmd"
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call GET $server1/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 3 ];
then
  echo "$cmd"
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call GET $server2/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 3 ];
then
  echo "$cmd"
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call POST $server2/bar"
eval $cmd
if [ "$result" -ne 200 ];
then
  echo "$cmd"
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call GET $server1/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 4 ];
then
  echo $cmd
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

cmd="call GET $server2/"
eval $cmd
if [ "$result" -ne 200 ] || [ "$body_line_count" -ne 4 ];
then
  echo $cmd
  echo -e "$result"
  echo -e "$body"
  killall httpfs
  exit 1
fi

killall httpfs
