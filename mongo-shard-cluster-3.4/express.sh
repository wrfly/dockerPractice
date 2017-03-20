#!/bin/bash

sleep 1
/portcheck

#sleep 30 for setup
sleep 30 #for setup

tini -- node app
