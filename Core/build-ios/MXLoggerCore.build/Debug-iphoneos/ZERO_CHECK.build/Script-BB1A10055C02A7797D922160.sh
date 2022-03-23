#!/bin/sh
set -e
if test "$CONFIGURATION" = "Debug"; then :
  cd /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios
  make -f /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "Release"; then :
  cd /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios
  make -f /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "MinSizeRel"; then :
  cd /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios
  make -f /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios/CMakeScripts/ReRunCMake.make
fi
if test "$CONFIGURATION" = "RelWithDebInfo"; then :
  cd /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios
  make -f /Users/dongjiayi/Documents/github/BlingLogger/Core/build-ios/CMakeScripts/ReRunCMake.make
fi

