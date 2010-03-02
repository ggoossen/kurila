#!/usr/bin/env perl

# Copyright (C) 2005  Joshua Hoblitt
#
# $Id$



use Test::More tests => 1

use Pod::Find < qw( contains_pod )

do
    ok: (contains_pod: 't/pod/contains_pod.xr'), "contains pod"

