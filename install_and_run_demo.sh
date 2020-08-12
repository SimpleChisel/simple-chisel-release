#!/bin/sh
pushd simple-chisel && sbt publishLocal && popd  && pushd simple-chisel-demo && make clean && make && popd
