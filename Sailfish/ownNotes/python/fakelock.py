# -*- coding: utf-8 -*-

class Fakelock:
    """Fake a WebDAV LOCK request.

    OwnCloud doesn't support WebDAV LOCKs, which return a 501 error. This class
    fakes the interface so that the locking code can be kept in the sync
    code but not have it actually do anything.

    It doesn't provide any locking functionality, it just offers an interface
    to allow 'with' blocks that have no effect.

    See ownCloud issue #17732 for details about the lack of WebDAV LOCKs:
    https://github.com/owncloud/core/issues/17732
    """
    def __init__(self):
        """Do nothing"""
        pass

    def __enter__(self):
        """Do nothing"""
        pass

    def __exit__(self, exc, exctype, exctb):
        """Do nothing"""
        pass


