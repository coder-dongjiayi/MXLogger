#!/bin/bash
rm -r build-ios
mkdir build-ios
cd build-ios

cmake .. -G Xcode -DCMAKE_TOOLCHAIN_FILE=./ios.toolchain.cmake -DPLATFORM=OS64 -DARCHS=arm64 -DDEPLOYMENT_TARGET=12.2 -DENABLE_STRICT_TRY_COMPILE=TRUE -DENABLE_VISIBILITY=TRUE -DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM=UBX9CH9GDX
cmake --build . --config Debug
#cmake --build . --config Release