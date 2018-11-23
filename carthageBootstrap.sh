#!/bin/bash

set -e
set -o pipefail

if ! command -v carthage; then
  echo "build needs 'carthage' to bootstrap dependencies"
  echo "You can install it using brew. E.g. $ brew install carthage"
  exit 1;
fi

echo "start chekout dependencies..."

carthage checkout

echo "remove ./Carthage/Checkouts/FBSimulatorControl/fbsimctl"

echo "Because we just need FBSimulatorControl.xcodeproj"

rm -rf "./Carthage/Checkouts/FBSimulatorControl/fbsimctl"


echo "start build dependencies..."

carthage build --platform Mac

echo "carthage checkout and build success."
