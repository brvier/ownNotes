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
            },
            'WebDav': {
                'url': 'https://owncloud.khertan.net/remote.php/webdav/',
                'login': 'demo',
                'password': 'demo',
                'remoteFolder': 'Notes',
                'merge': True,
                'nosslcheck': False,
                'startupsync': False
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
                    print(jsondata)
                    for k, v in list(jsondata.items()):
                        if type(v) is dict:
                            self._settings[k].update(v)
                        else:
                            self._settings[k] = v
        else:
            self._write()
        print(self._settings)

    def get(self, section, option):
        if not self._settings:
            self._read()
        return self._settings[section][option]

    def set(self, section, option, value):
        if not self._settings:
            self._read()
        self._settings[section][option] = value
        self._write()


if __name__ == '__main__':
    Settings()
