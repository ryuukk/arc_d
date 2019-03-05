#!/bin/bash

BUILD_TARGET=debug
ARCH=x86_64
COMPILER=dmd # ldc2, dmd

echo "Wich sample to run:"

select d
in samples/*;
do test -n ">> $d" && break; echo ">>> Invalid Selection";
done

result=$(basename $d)
result=${result:3} 

echo "Running $d -> $result"

dub run :$result --arch=$ARCH --build=$BUILD_TARGET --compiler=$COMPILER