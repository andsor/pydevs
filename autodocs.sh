#!/bin/sh

while inotifywait -qq -r -e modify -e create -e move -e delete \
       	--exclude '\.sw.?$|^_build' docs devs
do
	clear
	python setup.py docs
	sleep 1
done
