#!/bin/env bash

./.github/install-dependencies.sh

autoreconf -iv
eval `perl -V:siteprefix`
./configure --prefix=$siteprefix && make
perl Build.PL
