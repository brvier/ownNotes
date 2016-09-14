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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import os
import json
#import SimpleAES
import hashlib
import pyaes


class Settings(object):

    '''Config object'''

    def __init__(self,):
        self._settings = None
        if not os.path.exists(os.path.expanduser('~/.ownnotes.conf')):  # FIXME
            self._get_defaults()
            self._write()

    def _get_defaults(self):
        ''' Write the default config'''
        self._settings = {
            'Display': {
                'fontsize': 18,
                'fontfamily': 'Nokia Pure',
                'header': True,
                'covernote' : '',
            },
            'WebDav': {
                'url': 'https://owncloud.khertan.net/remote.php/webdav/',
                'login': 'demo',
                'password': '',
                'remoteFolder': 'Notes',
                'merge': True,
                'nosslcheck': False,
                'startupsync': False,
                'debug': False
            },
            'KhtCms': {
                'url': 'https://khertan.net/publish_api.php',
                'nosslcheck': False,
                'apikey': ''
            },
            'Scriptogram': {
                'userid': '678909876',
            },
        }
        return self._settings

    def _write(self, ):
        if not self._settings:
            self._settings = self._read

        with open(os.path.expanduser('~/.ownnotes.conf'), 'w') \
                as configfile:
            json.dump(self._settings, configfile)

    def _read(self,):
        self._get_defaults()
        if os.path.exists(os.path.expanduser('~/.ownnotes.conf')):
            with open(os.path.expanduser('~/.ownnotes.conf'), 'r') \
                    as configfile:
                    jsondata = json.load(configfile)
                    for k, v in list(jsondata.items()):
                        if type(v) is dict:
                            self._settings[k].update(v)
                        else:
                            self._settings[k] = v
        else:
            self._write()

    def get(self, section, option):
        if not self._settings:
            self._read()

        #Obscure ...
        if (section == 'WebDav' and option == 'password'):
            if os.path.exists('/etc/machine-id'):
                with open('/etc/machine-id', 'r') as fh:
                    aes = pyaes.AESModeOfOperationCTR(
                        hashlib.sha256(fh.read().encode('utf-8')).digest())
                    return aes.decrypt(self._settings[section][option])

        return self._settings[section][option]

    def set(self, section, option, value):
        if not self._settings:
            self._read()

        if (section == 'WebDav' and option == 'password'):
            if os.path.exists('/etc/machine-id'):
                with open('/etc/machine-id', 'r') as fh:
                    aes = pyaes.AESModeOfOperationCTR(
                        hashlib.sha256(fh.read().encode('utf-8')).digest())
                    self._settings[section][option] = \
                        aes.encrypt(value)
            else:
                self._settings[section][option] = value
        else:
            self._settings[section][option] = value

        self._write()


if __name__ == '__main__':
    Settings()
    #Settings().set('WebDav', 'password', 'test')
    #assert(Settings().get('WebDav', 'password') == 'test')
