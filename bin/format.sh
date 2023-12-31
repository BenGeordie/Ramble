#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR/..

python3 -m black . --preview