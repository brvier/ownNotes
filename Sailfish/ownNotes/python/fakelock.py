# -*- coding: utf-8 -*-

"""Fake a WebDAV LOCK request.

OwnCloud doesn't support WebDAV LOCKs, which return a 501 error. This class
fakes the interface so that the locking code can be kept in the sync
code but not have it actually do anything.

It doesn't provide any locking functionality, it just offers an interface
to allow 'with' blocks that have no effect.

See ownCloud issue #17732 for details about the lack of WebDAV LOCKs:
https://github.com/owncloud/core/issues/17732
"""

import contextlib

@contextlib.contextmanager

def fakelock():
    """
    Empty context manager that does nothing. Courtesey of @brett_lempereurs
    pithiness :)
    https://gist.github.com/brett-lempereur/31c67d8d3b251bd5175e104e656d781c
    https://twitter.com/brettlempereur/status/773566420709994496
    """
    yield
