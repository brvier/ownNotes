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


class KhtCMS():

    def publish(self, url, title, type, text, apikey, verify_ssl):

        datas = {'apiKey': apikey,
                 'title': title,
                 'type': type,
                 'content': text}

        res = requests.post(url, data=datas, verify=verify_ssl)
        if res.status_code != requests.codes.ok:
            raise NetworkError('HTTP Error : %d' % res.status_code)
        else:
            print(res.text)
            jdata = res.json()
            if 'status' not in jdata:
                raise NetworkError('Invalid answer from KhtCMS API'
                                   % jdata['reason'])
            if jdata['status'] != 'success':
                raise NetworkError('%s' % jdata['reason'])
