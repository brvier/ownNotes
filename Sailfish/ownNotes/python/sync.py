#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2011 Benoit HERVIER <khertan@khertan.net>
# Licenced under GPLv3

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; version 3 only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
# GNU General Public License for more details.

import os.path
import os
import threading
from settings import Settings
import time
import json
import rfc822py3 as rfc822
import datetime
import requests
import tinydav
import logger
from fakelock import Fakelock

INVALID_FILENAME_CHARS = '\/:*?"<>|'


class IncorrectSyncParameters(Exception):
    pass


class SSLError(Exception):
    pass


class NetworkError(Exception):
    pass


def _getValidFilename(filepath):
    dirname, filename = os.path.dirname(filepath), os.path.basename(filepath)
    return os.path.join(dirname, ''.join(car for car in filename
                                         if car not in INVALID_FILENAME_CHARS))


def local2utc(secs):
    if time.daylight:
        return secs - time.timezone
    else:
        return secs - time.altzone


def webdavPathJoin(path, *args):
    for arg in args:
        if path.endswith('/'):
            path = path + arg
        else:
            path = path + '/' + arg
    return path


class localClient(object):

    def __init__(self, logger):
        self.basepath = os.path.expanduser('~/.ownnotes/')  # Use xdg env
        self._check_notes_folder()
        self.logger = logger

    def _check_notes_folder(self,):
        if not os.path.exists(self.basepath):
            os.makedirs(self.basepath)

    def get_abspath(self, relpath, asFolder=False):
        abspath = os.path.join(self.basepath, relpath)
        if asFolder and not abspath.endswith('/'):
            abspath += os.path.sep
        return abspath

    def get_relpath(self, abspath):
        return os.path.relpath(abspath, self.basepath)

    def set_mtime(self, relpath, mtime):
        os.utime(self.get_abspath(relpath), (-1, mtime))

    def get_mtime(self, abspath):
        return round(os.path.getmtime(abspath))

    def get_md5(self, relpath):
        import hashlib
        with open(self.get_abspath(relpath), 'rb') as fh:
            return hashlib.md5(fh.read()).digest()

    def get_files_index(self,):
        index = {}
        for root, folders, files in os.walk(self.basepath):
            if self.get_relpath(root) != \
                    '.merge.sync':
                for filename in files:
                    index[self.get_relpath(os.path.join(root, filename))] = \
                        self.get_mtime(os.path.join(root, filename))

        try:
            del index['.index.sync']
        except KeyError:
            pass

        return index

    def rm(self, relpath):
        path = self.get_abspath(relpath)
        if os.path.isdir(path):
            os.rmdir(path)
        else:
            os.remove(path)

    def get_size(self, relpath):
        abspath = self.get_abspath(relpath)
        return os.stat(abspath).st_size


class WebdavClient(object):

    def __init__(self, logger):

        settings = Settings()

        self.url = settings.get('WebDav', 'url')
        self.login = settings.get('WebDav', 'login')
        self.passwd = settings.get('WebDav', 'password')
        self.basepath = requests.utils.urlparse(self.url).path
        self.remotefolder = settings.get('WebDav', 'remoteFolder')
        self.nosslcheck = settings.get('WebDav', 'nosslcheck')
        self.time_delta = None
        self.wc = None
        self.locktoken = None
        self.logger = logger

    def connect(self,):

        urlparsed = requests.utils.urlparse(self.url)

        self.wc = tinydav.WebDAVClient(host=urlparsed.netloc,
                                       protocol=urlparsed.scheme,
                                       nosslcheck=self.nosslcheck)

        self.wc.setbasicauth(self.login.encode('utf-8'),
                             self.passwd.encode('utf-8'))
        self.time_delta = None

        local_time = datetime.datetime.utcnow()

        response = self.wc.options('/').headers.get('date')
        if response is None:
            response = self.wc.options('/').headers.get('Date')

        remote_datetime = \
            rfc822.parsedate(response)

        self.time_delta = time.mktime(local_time.utctimetuple()) \
            - time.mktime(remote_datetime)

        self._check_notes_folder()

        self.logger.logger.debug('Response :  %s',
                                 response)

        self.logger.logger.info('Connected to %s : Time delta %s',
                                urlparsed.netloc, str(self.time_delta))

        return self.time_delta

    def _check_notes_folder(self,):
        response = self.wc.propfind(uri=self.basepath,
                                    names=True,
                                    depth=1)
        ownnotes_folder_exists = False
        ownnotes_remote_folder = self.get_abspath('')
        if response.real != 207:
            is_connected = False
        else:
            is_connected = True
            for res in response:
                self.logger.logger.debug('Check Notes Folder %s : %s',
                                         ownnotes_remote_folder, res.href)
                if (res.href == ownnotes_remote_folder):
                    ownnotes_folder_exists = True
            if not ownnotes_folder_exists:
                with self.locktoken:
                    self.wc.mkcol(ownnotes_remote_folder)
                    self.logger.logger.debug(
                        'Exists or create mkcol : %s', ownnotes_remote_folder)
        return is_connected

    def exists_or_create(self, relpath):
        self.logger.logger.debug(
            'Exists or create %s' % self.get_abspath(relpath))
        response = self.wc.propfind(uri=self.get_abspath('', asFolder=True),
                                    names=True,
                                    depth=1)

        if response.real != 207:
            return False
        else:
            for res in response:
                self.logger.logger.debug('Exists or create %s : %s',
                                         self.get_abspath(relpath),
                                         res.href.rstrip('/'))
                if ((res.href == self.get_abspath(relpath))
                        or (res.href.rstrip('/')
                            == self.get_abspath(relpath))):
                    return True

        with self.locktoken:
            self.logger.logger.debug(
                'Exists or create mkcol : %s',
                self.get_abspath(relpath, asFolder=True))
            self.wc.mkcol(self.get_abspath(relpath, asFolder=True))

    def upload(self, relpath, fh):
        with self.locktoken:
            self.logger.logger.debug('Put : %s', self.get_abspath(relpath))
            self.wc.put(self.get_abspath(relpath), fh)

    def download(self, relpath, fh):
        self.logger.logger.debug('Get : %s', self.get_abspath(relpath))
        fh.write(self.wc.get(self.get_abspath(relpath)).content)

    def rm(self, relpath):
        with self.locktoken:
            self.logger.logger.debug('Delete : %s', self.get_abspath(relpath))
            self.wc.delete(self.get_abspath(relpath))

    def get_abspath(self, relpath, asFolder=False):
        abspath = self.basepath

        if abspath.endswith('/'):
            abspath += self.remotefolder
        else:
            abspath += '/' + self.remotefolder
        if abspath.endswith('/'):
            abspath += relpath
        else:
            abspath += '/' + relpath
        if asFolder and not abspath.endswith('/'):
            abspath += '/'
        return abspath

    def get_relpath(self, abspath):
        basepath = self.basepath
        if basepath.endswith('/'):
            basepath += self.remotefolder
        else:
            basepath += '/' + self.remotefolder
        return os.path.relpath(abspath, basepath)

    def get_mtime(self, relpath):
        response = self.wc.propfind(uri=self.get_abspath(relpath))
        if response.real != 207:
            raise NetworkError('Can\'t get mtime file on webdav host')
        else:
            for res in response:
                return round(time.mktime(rfc822.parsedate(
                    res.get('getlastmodified').text)))

    def get_files_index(self, path=''):
        index = {}

        abspath = self.get_abspath(path, asFolder=True)
        response = self.wc.propfind(uri=abspath,
                                    names=True,
                                    depth='1')
        # We can t use infinite depth some owncloud version
        # didn t support it

        if response.real == 207:
            for res in response:
                if len(res.get('resourcetype').getchildren()) == 0:
                    index[requests.utils.unquote(self.get_relpath(res.href))] \
                        = round(time.mktime(rfc822.parsedate(
                            res.get('getlastmodified').text)))
                else:
                    # Workarround for infinite depth
                    if res.href != abspath:
                        index.update(
                            self.get_files_index(
                                path=self.get_relpath(res.href)))

        elif response.real == 200:
            raise NetworkError('Wrong answer from server')

        else:
            raise NetworkError('Can\'t list file on webdav host')

        return index

    def move(self, srcrelpath, dstrelpath):
        '''Move/Rename a note on webdav'''
        with self.locktoken:
            self.logger.logger.debug('Move : %s -> %s',
                                     self.get_abspath(srcrelpath),
                                     self.get_abspath(srcrelpath))
            self.wc.move(self.get_abspath(srcrelpath),
                         self.get_abspath(dstrelpath),
                         depth='infinity',
                         overwrite=True)

    def lock(self, relpath=''):
        '''ownCloud no longer supports WebDAV file LOCKs, so just set up an
        empty interface'''
        self.locktoken = Fakelock()
        return
        # The original code to execute, if locking were implemented, follows
        abspath = self.get_abspath(relpath, asFolder=True)
        if relpath:
            self.locktoken = self.wc.lock(uri=abspath, timeout=60)
        else:
            self.locktoken = self.wc.lock(uri=abspath,
                                          depth='Infinity',
                                          timeout=300)

    def unlock(self, relpath=None):
        '''ownCloud no longer supports WebDAV file LOCKs, so we do nothing'''
        return
        # The original code to execute, if locking were implemented, follows
        if self.locktoken:
            self.wc.unlock(uri_or_lock=self.locktoken)


class Sync(object):

    '''Sync class'''

    def __init__(self,):
        self._running = False
        self._lock = None

        settings = Settings()
        self.logger = logger.Logger(
            debug=settings.get('WebDav', 'debug'))

        # TODO
        # Duplicate, launched in qml
        #if settings.get('WebDav', 'startupsync') is True:
        #    self.launch()

    def launch(self):
        ''' Sync the notes in a thread'''
        if not self._get_running():
            self._set_running(True)
            self.thread = threading.Thread(target=self.sync)
            self.thread.start()
            return True
        else:
            return True

    def launch_push_note(self, path):
        self.thread = threading.Thread(target=self._wpushNote, args=[path, ])
        self.thread.start()
        return True

    def sync(self):
        wdc = WebdavClient(self.logger)
        try:
            wdc.connect()
            time_delta = wdc.time_delta

            ldc = localClient(self.logger)

            # Get remote filenames and timestamps
            remote_filenames = wdc.get_files_index()

            # Get local filenames and timestamps
            local_filenames = ldc.get_files_index()

            wdc.lock()

            previous_remote_index, \
                previous_local_index = self._get_sync_index()

            # Delete remote file deleted
            for filename in set(previous_remote_index) \
                    - set(remote_filenames):
                if filename in list(local_filenames.keys()):
                    if int(local2utc(previous_remote_index[filename] -
                                     time_delta))  \
                            - int(local_filenames[filename]) >= -1:
                        self._local_rm(ldc, filename)
                        del local_filenames[filename]
                    else:
                        # Else we have a conflict local file is newer than
                        # deleted one
                        self._upload(wdc, ldc, filename)

            # Delete local file deleted
            for filename in set(previous_local_index) \
                    - set(local_filenames):
                if filename in remote_filenames:
                    mtime = wdc.get_mtime(filename)
                    if previous_remote_index[filename] == mtime:
                        self._remote_rm(wdc, filename)
                        del remote_filenames[filename]
                    else:
                        # We have a conflict remote file was modifyed
                        # since last sync
                        self._download(wdc, ldc, filename)

            # What to do with new remote file
            for filename in set(remote_filenames) \
                    - set(local_filenames):
                self._download(wdc, ldc, filename, filename)

            # What to do with new local file
            for filename in set(local_filenames) \
                    - set(remote_filenames):
                self._upload(wdc, ldc, filename)

            # Check what's updated remotly
            rupdated = [filename for filename
                        in (set(remote_filenames).
                            intersection(previous_remote_index))
                        if remote_filenames[filename]
                        != previous_remote_index[filename]]
            lupdated = [filename for filename
                        in (set(local_filenames).
                            intersection(previous_local_index))
                        if local_filenames[filename]
                        != previous_local_index[filename]]
            for filename in set(rupdated) - set(lupdated):
                self._download(wdc, ldc, filename)
            for filename in set(lupdated) - set(rupdated):
                self._upload(wdc, ldc, filename)

            # Updated Both Side
            for filename in set(lupdated).intersection(rupdated):

                # Avoid false detect
                if abs(local2utc(remote_filenames[filename]
                                 - time_delta)
                       - local_filenames[filename]) == 0:
                    pass
                elif local2utc(remote_filenames[filename]
                               - time_delta) \
                        > local_filenames[filename]:
                    self._conflictLocal(wdc, ldc, filename)
                elif local2utc(remote_filenames[filename]
                               - time_delta) \
                        < local_filenames[filename]:
                    self._conflictServer(wdc, ldc, filename)
                else:
                    pass

            # Build and write index
            self._write_index(wdc, ldc)

            # Unlock the collection
            wdc.unlock()

        except requests.exceptions.SSLError as err:
            raise SSLError('SSL Certificate is not valid, or is self signed')

        except Exception as err:
            import traceback
            self.logger.logger.error(traceback.format_exc())
            wdc.unlock()
            raise err

        self._set_running(False)
        return True

    def push_note(self, relpath):
        ''' Given full path of a textual note file, push that file to the
            remote server '''
        self._set_running(True)

        ldc = localClient()

        # Create Connection
        wdc = WebdavClient()
        wdc.connect()

        wdc.lock(relpath)

        # Get mtime
        remote_mtime = self._get_mtime(relpath)
        local_mtime = ldc.get_mtime(ldc.get_abspath(relpath))

        if local_mtime >= local2utc(remote_mtime - wdc.time_delta):
            self._upload(wdc, ldc, relpath)
        else:
            self._uploadConflict(wdc, ldc, relpath)

        wdc.unlock(relpath)

        self._set_running(False)

    def _conflictServer(self, wdc, ldc, path):
        '''Priority to local'''

        conflict_path = os.path.splitext(path)[0] + '.Conflict.txt'  # FIXME

        self._download(wdc, ldc,
                       path,
                       conflict_path)

        # Test if it s a real conflict
        if ldc.get_size(conflict_path) == 0:  # Test size to avoid ownCloud Bug
            ldc.rm(conflict_path)

        elif ldc.get_md5(path) == ldc.get_md5(conflict_path):
            ldc.rm(conflict_path)

        self._upload(wdc, ldc, path)

    def _conflictLocal(self, wdc, ldc, relpath):
        '''Priority to server'''

        conflict_path = os.path.splitext(relpath)[0] + '.Conflict.txt'  # FIXME

        ldc.rename(relpath, conflict_path)
        self._download(wdc, ldc, relpath)

        # Test if it s a real conflict
        if ldc.getsize(relpath) == 0:  # Test size to avoid ownCloud Bug
            ldc.remove(relpath)
            ldc.rename(conflict_path, relpath)
        elif ldc.get_md5(relpath) == ldc.get_md5(conflict_path):
            ldc.remove(conflict_path)
        else:
            self._upload(wdc, ldc, conflict_path)

    def get_last_sync_datetime(self):
        try:
            # TODO Use XDG Env
            return time.strftime('%x %X',
                                 time.localtime(
                                     os.path.getmtime(
                                         os.path.join(
                                             os.path.expanduser(
                                                 '~/.ownnotes/'),
                                             '.index.sync'))))
        except:
            return ''

    def _get_sync_index(self):
        index = {'remote': [], 'local': []}
        try:
            with open(
                    os.path.join(
                        os.path.expanduser('~/.ownnotes/'),  # Use xdg env,
                        '.index.sync'),
                    'r') as fh:
                index = json.load(fh)
        except (IOError, TypeError, ValueError) as err:
            self.logger.logger.info((
                'First sync detected or error: %s'
                % str(err)))
        if type(index) == list:
            return index  # for compatibility with older release
        return (index['remote'], index['local'])

    def _write_index(self, wdc, ldc):
        '''Generate index for the next sync and base for merge'''
        import shutil
        #import glob
        index = {'remote': wdc.get_files_index(),
                 'local': ldc.get_files_index()}
        with open(os.path.join(
                os.path.expanduser('~/.ownnotes/'),  # Use xdg env
                '.index.sync'), 'w') as fh:
            json.dump(index, fh)
            merge_dir = ldc.get_abspath('.merge.sync/')
            if os.path.exists(merge_dir):
                shutil.rmtree(merge_dir)
            print('index written')

    def _rm_remote_index(self,):
        '''Delete the remote index stored locally'''
        try:
            with open(os.path.join(
                    os.path.expanduser('~/.ownnotes/'),  # Use xdg env
                    '.index.sync'), 'r') as fh:
                index = json.load(fh)
            with open(os.path.join(
                    os.path.expanduser('~/.ownnotes/'),  # Use xdg env
                    '.index.sync'), 'w') as fh:
                json.dump(({}, index[1]), fh)
        except:
            self.logger.logger.info('No remote index stored locally')

    def _upload(self, wdc, ldc, local_relpath, remote_relpath=None):
        if not remote_relpath:
            remote_relpath = local_relpath
        rdirname = os.path.dirname(remote_relpath)

        wdc.exists_or_create(rdirname)

        mtime = None
        with open(ldc.get_abspath(local_relpath), 'rb') as fh:
            wdc.upload(remote_relpath, fh)
            mtime = local2utc(wdc.get_mtime(remote_relpath)) - wdc.time_delta

        if mtime:
            ldc.set_mtime(local_relpath, mtime)

    def _download(self, wdc, ldc, remote_relpath, local_relpath=None):
        if not local_relpath:
            local_relpath = remote_relpath

        if not os.path.exists(os.path.dirname(ldc.get_abspath(local_relpath))):
            os.makedirs(os.path.dirname(ldc.get_abspath(local_relpath)))

        mtime = None
        with open(ldc.get_abspath(local_relpath), 'wb') as fh:
            wdc.download(remote_relpath, fh)
            mtime = wdc.get_mtime(remote_relpath) - wdc.time_delta

        if mtime:
            ldc.set_mtime(local_relpath, mtime)

    def _remote_rm(self, wdc, relpath):
        wdc.rm(relpath)

    def _local_rm(self, ldc, relpath):
        ldc.rm(relpath)

    def _unlock(self, webdavConnection):
        if (webdavConnection is not None) and (self._lock is not None):
            webdavConnection.path = self._get_notes_path()
            webdavConnection.unlock(self._lock)
            self._lock = None

    def _get_notes_path(self):
        khtnotesPath = requests.utils.urlparse(self.webdavUrl).path
        if not khtnotesPath.endswith('/'):
            return khtnotesPath + '/' + self._remoteDataFolder + '/'
        else:
            return khtnotesPath + self._remoteDataFolder + '/'

    def __get_remote_filenames(self, webdavConnection, path):
        index = {}
        webdavConnection.path = path
        for resource, properties in webdavConnection.getCollectionContents():
            if properties.getResourceType() != 'resource':
                index.update(self.__get_remote_filenames(webdavConnection,
                                                         resource.path))
            else:
                index[self.remoteBasename(resource.path)] = \
                    time.mktime(properties.getLastModified())
        return index

    def _get_remote_filenames(self, webdavConnection):
        '''Check Remote Index'''
        webdavConnection.path = self._get_notes_path()

        index = self.__get_remote_filenames(webdavConnection,
                                            self._get_notes_path())

        try:
            del index['']
        except KeyError:
            pass

        try:
            del index['.index.sync']
        except KeyError:
            pass
        return index

    def _get_local_filenames(self):
        index = {}
        for root, folders, files in os.walk(self._localDataFolder):
            if self.localBasename(root) != '.merge.sync':
                for filename in files:
                    index[self.localBasename(os.path.join(root,
                                                          filename))] = \
                        round(os.path.getmtime(
                              os.path.join(root, filename)))

        try:
            del index['.index.sync']
        except KeyError:
            pass

        return index

    def _get_running(self):
        return self._running

    def _set_running(self, b):
        self._running = b


if __name__ == '__main__':
    s = Sync()
    s.sync()
