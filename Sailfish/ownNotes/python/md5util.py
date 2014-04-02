#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2007 Khertan khertan@khertan.net
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; version 2 only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# md5hash
#
# 2004-01-30
# Nick Vargish
#
# 2012-05-31
# Benoit HERVIER (Khertan) use now hashlib
#
# Simple md5 hash utility for generating md5 checksums of files.
#
# usage: md5hash <filename> [..]
#
# Use '-' as filename to sum standard input.

from hashlib import md5
import sys


def sumfile(fobj):
    '''Returns an md5 hash for an object with read() method.'''
    m = md5()
    while True:
        d = fobj.read(8096)
        if not d:
            break
        m.update(d)
    return m.hexdigest()


def md5sum(fname):
    '''Returns an md5 hash for file fname, or stdin if fname is "-".'''
    if fname == '-':
        ret = sumfile(sys.stdin)
    else:
        try:
            f = file(fname, 'rb')
        except:
            return 'Failed to open file'
        ret = sumfile(f)
        f.close()
    return ret


# if invoked on command line, print md5 hashes of specified files.
if __name__ == '__main__':
    for fname in sys.argv[1:]:
        print('%32s  %s' % (md5sum(fname), fname))
