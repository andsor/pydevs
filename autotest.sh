#!/bin/sh

while inotifywait -qq -r -e modify -e create -e move -e delete \
       --exclude '\.sw.?$' tests devs
do
	clear
	py.test --cov=devs tests
	sleep 1
done
