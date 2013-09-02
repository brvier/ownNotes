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

import requests


class NetworkError(Exception):
    pass


class Scriptogram():
    app_key = 'v2sgBSIBgWfb942b5960126f830ed8c44f8839d21a'

    def publish(self, title, user_id, text):
        url = 'http://scriptogr.am/api/article/post/'
        datas = {'app_key': self.app_key,
                 'user_id': user_id,
                 'name': title,
                 'text': text}

        res = requests.post(url, data=datas)
        if res.status_code != requests.codes.ok:
            raise NetworkError('HTTP Error : %d' % res.status_code)
        else:
            if 'status' not in res.json():
                raise NetworkError('Invalid answer from scriptogr.am API'
                                   % res.json()['reason'])
            if res.json()['status'] != 'success':
                raise NetworkError('%s' % res.json()['reason'])
