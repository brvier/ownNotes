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
import logging
import logging.handlers
import md5util
#from webdav.Connection import WebdavError
import urllib.parse
import http
import datetime

from tinydav import WebDAVClient


INVALID_FILENAME_CHARS = '\/:*?"<>|'


class IncorrectSyncParameters(Exception):
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

    def __init__(self,):
        self.basepath = os.path.expanduser('~/.ownnotes/')  # Use xdg env
        self._check_notes_folder()

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

    def get_mtime(self, abspath):
        return round(os.path.getmtime(abspath))

    def get_md5(self, relpath):
        pass

    def get_files_index(self,):
        index = {}
        for root, folders, files in os.walk(str(self.basepath)):
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
            os.rmdir(path)


class WebdavClient(object):

    def __init__(self,):

        settings = Settings()

        self.url = settings.get('WebDav', 'url')

        self.login = settings.get('WebDav', 'login')
        self.passwd = settings.get('WebDav', 'password')
        self.basepath = urllib.parse.urlparse(self.url).path
        self.remotefolder = settings.get('WebDav', 'remoteFolder')
        self.timedelta = None
        self.wc = None
        self.lock = None

    def connect(self,):
        from urllib.parse import urlparse
        urlparsed = urlparse(self.url)

        self.wc = WebDAVClient(host=urlparsed.netloc,
                               protocol=urlparsed.scheme)

        self.wc.setbasicauth(self.login.encode('utf-8'),
                             self.passwd.encode('utf-8'))
        time_delta = None

        local_time = datetime.datetime.utcnow().replace(
            tzinfo=datetime.timezone.utc)
        response = self.wc.options('/').headers.get('Date')

        remote_datetime = \
            http.client.email.utils.parsedate_to_datetime(response)
        self.timedelta = local_time.timestamp() - remote_datetime.timestamp()

        self._check_notes_folder()

        return time_delta

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
                if (res.href == ownnotes_remote_folder):
                    ownnotes_folder_exists = True
            if not ownnotes_folder_exists:
                self.wc.mkcol(ownnotes_remote_folder)
        return is_connected

    def exists_or_create(self, relpath):
        response = self.wc.propfind(uri=self.get_abspath(''),
                                    names=True,
                                    depth=1)

        if response.real != 207:
            return False
        else:
            for res in response:
                if (res.href == self.get_abspath(relpath)):
                    return True

        self.wc.mkcol(self.get_abspath(relpath))

    def upload(self, fh, relpath):
        self.wc.put(self.get_abspath(relpath), fh)

    def download(self, relpath, fh):
        fh.write(self.wc.get(self.get_abspath(relpath)))

    def rm(self, relpath):
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

    def get_files_index(self,):
        index = {}

        abspath = self.get_abspath('', asFolder=True)

        response = self.wc.propfind(uri=abspath,
                                    names=True,
                                    depth='infinity')

        if response.real != 207:
            raise NetworkError('Can\'t list file on webdav host')
        else:
            for res in response:
                print(res.href)
                index[self.get_relpath(res.href)] = \
                    round(http.client.email.utils.parsedate_to_datetime(
                        res.get('getlastmodified').text).timestamp())

        return index

    def move(self, srcrelpath, dstrelpath):
        '''Move/Rename a note on webdav'''
        self.wc.move(self.get_abspath(srcrelpath),
                     self.get_abspath(dstrelpath),
                     depth='infinity',
                     overwrite=True)


class Sync(object):

    '''Sync class'''

    def __init__(self,):
        self._running = False
        self._lock = None

    def launch(self):
        ''' Sync the notes in a thread'''
        if not self._get_running():
            self._set_running(True)
            self.thread = threading.Thread(target=self.sync)
            self.thread.start()
            return True
        else:
            return True

    def push_note(self, path):
        self.thread = threading.Thread(target=self._wpushNote, args=[path, ])
        self.thread.start()

    def sync(self):
        try:
            wdc = WebdavClient()
            wdc.connect()
            time_delta = wdc.timedelta

            ldc = localClient()

            # Get remote filenames and timestamps
            remote_filenames = wdc.get_files_index()

            # Get local filenames and timestamps
            local_filenames = ldc.get_files_index()

            print(remote_filenames)
            print(local_filenames)

            previous_remote_index, \
                previous_local_index = self._get_sync_index()

            print(previous_remote_index, previous_local_index)

            # Delete remote file deleted
            for filename in set(previous_remote_index) \
                    - set(remote_filenames):
                if filename in list(local_filenames.keys()):
                    if int(local2utc(previous_remote_index[filename] -
                                     time_delta))  \
                            - int(local_filenames[filename]) >= -1:
                        self._local_rm(filename)
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
                       - time_delta) - local_filenames[filename]) == 0:
                    print('Ignored %s' % filename)
                elif local2utc(remote_filenames[filename]
                               - time_delta) \
                        > local_filenames[filename]:
                    self._conflictLocal(wdc, ldc, filename)
                elif local2utc(remote_filenames[filename]
                               - time_delta) \
                        < local_filenames[filename]:
                    self._conflictServer(wdc, ldc, filename)
                else:
                    print('Ignored %s' % filename)

            # Build and write index
            self._write_index(wdc)

            # Unlock the collection
            wdc.unlock()
            print('Sync end')

        except Exception as err:
            raise err

        return True

    def note_push(self, relpath):
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
        print('conflictServer: %s' % path)

        conflict_path = os.path.splitext(path)[0] + '.Conflict.txt'

        self._download(wdc, ldc,
                       path,
                       conflict_path)

        # Test if it s a real conflict
        if ldc.get_size(conflict_path) == 0:  # Test size to avoid ownCloud Bug
            ldc.rm(conflict_path)

        elif ldc.md5sum(path) == ldc.md5sum(conflict_path):
            ldc.rm(conflict_path)

        self._upload(wdc, ldc, path)

    def _conflictLocal(self, wdc, ldc, relpath):
        '''Priority to server'''
        print('conflictLocal: %s', relpath)
        conflict_path = os.path.splitext(relpath)[0] + '.Conflict.txt'

        ldc.rename(relpath, conflict_path)
        self._download(wdc, ldc, relpath)

        # Test if it s a real conflict
        if ldc.getsize(relpath) == 0:  # Test size to avoid ownCloud Bug
            ldc.remove(relpath)
            ldc.rename(conflict_path, relpath)
        elif ldc.md5sum(relpath) == ldc.md5sum(conflict_path):
            ldc.remove(conflict_path)
        else:
            self._upload(wdc, ldc, conflict_path)

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
            print(
                'First sync detected or error: %s'
                % str(err))
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
            json.dump(index, fh, ensure_ascii=False, encoding='utf-8')
            merge_dir = os.path.join(
                self._localDataFolder, '.merge.sync/')
            if os.path.exists(merge_dir):
                shutil.rmtree(merge_dir)

            # os.makedirs(merge_dir)
            # for filename in glob.glob(os.path.join(
            #        self._localDataFolder, '*.txt')):
            #    try:
            #        if os.path.isfile(filename):
            #            shutil.copy(filename,
            #                        os.path.join(
            #                            merge_dir,
            #                            self.localBasename(filename)))
            #    except IOError as err:
            #        print(err, 'filename:', filename, ' merge_dir:',
            #              merge_dir)

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
            self.logger.debug('No remote index stored locally')

    def _upload(self, wdc, local_filename, remote_filename):
        if not remote_filename:
            remote_filename = local_filename
        rdirname, rfilename = (os.path.dirname(remote_filename),
                               os.path.basename(remote_filename))

        if not wdc.exists(rdirname):
            wdc.mkcol(rdirname)

        lpath = os.path.join(self._localDataFolder, local_filename)

        with open(lpath, 'r') as fh:
            wdc.upload(fh)
            mtime = local2utc(wdc.get_mtime()) - wdc.timedelta
            os.utime(lpath, (-1, mtime))

    def _download(self, webdavConnection, remote_filename,
                  local_filename, time_delta):
        if not local_filename:
            local_filename = remote_filename
        self.logger.debug('Download %s to %s' %
                          (remote_filename, local_filename))
        rdirname, rfilename = (os.path.dirname(remote_filename),
                               os.path.basename(remote_filename))
        webdavConnection.path = webdavPathJoin(self._get_notes_path(),
                                               rdirname, rfilename)
        if not os.path.exists(os.path.join(self._localDataFolder,
                                           os.path.dirname(local_filename))):
            os.makedirs(os.path.join(self._localDataFolder,
                                     os.path.dirname(local_filename)))
        lpath = os.path.join(self._localDataFolder,
                             os.path.dirname(local_filename),
                             _getValidFilename(
                                 os.path.basename(local_filename)))
        webdavConnection.downloadFile(lpath)
        mtime = local2utc(time.mktime(webdavConnection
                                      .readStandardProperties()
                                      .getLastModified())) - time_delta
        os.utime(lpath, (-1, mtime))

    def _get_mtime(self, webdavConnection, remote_filename):
        rdirname, rfilename = (os.path.dirname(remote_filename),
                               os.path.basename(remote_filename))
        webdavConnection.path = webdavPathJoin(self._get_notes_path(),
                                               rdirname, rfilename)
        return time.mktime(webdavConnection
                           .readStandardProperties()
                           .getLastModified())

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
        khtnotesPath = urllib.parse.urlparse(self.webdavUrl).path
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
                index[str(self.remoteBasename(resource.path))] = \
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
        self.logger.debug('_get_remote_filenames: %s'
                          % str(index))
        return index

    def _get_local_filenames(self):
        index = {}
        for root, folders, files in os.walk(str(self._localDataFolder)):
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

        self.logger.debug('_get_local_filenames: %s'
                          % str(index))
        return index

    def _get_running(self):
        return self._running

    def _set_running(self, b):
        self._running = b


if __name__ == '__main__':
    s = Sync()
    s.launch()
