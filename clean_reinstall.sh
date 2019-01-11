#!/bin/bash

# check we are in the correct directory
if [ "$(grep "MAIN_PACKAGE" setup.py | head -n 1 | awk -F" = " '{print $2}')" != "\"devs\"" ]
  then echo "not correct dir, exiting"; exit 1
fi

# regenrate cython file
cd devs
rm devs.cpp
cython --cplus -X language_level=3 devs.pyx
cd ../
# clean build dirs
python setup.py clean
# delete installed module form virtualenv
rm -rf $VIRTUAL_ENV/lib/python*/site-packages/devs*
# now install
python setup.py install
