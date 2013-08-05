#!/usr/env python
# -*- coding: utf-8 -*-

""" ownNotes
    Copyright (C) 2013 Benoît HERVIER <khertan@khertan.net>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
"""

import os
import time
import codecs
import re
import htmlentitydefs
from settings import Settings
from sync import Sync

INVALID_FILENAME_CHARS = '\/:*?"<>|'
STRIPTAGS = re.compile(r'<[^>]+>')
STRIPHEAD = re.compile("<head>.*?</head>", re.DOTALL)

NOTESPATH = os.path.expanduser('~/.ownnotes/')

settings = Settings()
sync = Sync()

if not os.path.exists(NOTESPATH):
    os.makedirs(NOTESPATH)


def _getValidFilename(filepath):
    dirname, filename = os.path.dirname(filepath), os.path.basename(filepath)
    return os.path.join(dirname, ''.join(car for car in filename
                        if car not in INVALID_FILENAME_CHARS))


def _strongify(group):
    return '<b>%s</b>' % group.group(0)


def _emify(group):
    return '<i>%s</i>' % group.group(0)


def _linkify(group):
    return '<font color="#00FF00">%s</font>' % group.group(0)


def _titleify(group):
    return '<big><font color="#441144">%s</font></big>' % group.group(0)


def _undertitleify(group):
    return '<big><font color="#663366">%s</font></big>' % group.group(0)


def _colorize(text):
    regexs = ((re.compile(
        r'(\*|_){2}(.+?)(\*|_){2}',
        re.UNICODE), _strongify),
        (re.compile(
            r'(?<!\*|_)(\*|_)(?!\*|_)'
            '(.+?)(?<!\*|_)(\*|_)(?!\*|_)',
            re.UNICODE), _emify),
        (re.compile(
            r'\[(.*?)\]\([ \t]*(&lt;(.*?)&gt;|(.*?))'
            '([ \t]+(".*?"))?[ \t]*\)',
            re.UNICODE), _linkify),
        (re.compile(
            '^(.+)\n=+$',
            re.UNICODE | re.MULTILINE), _titleify),
        (re.compile(
            r'^(.+)\n-+$',
            re.UNICODE | re.MULTILINE), _undertitleify),
        (re.compile(
            r'^#(.+)#$',
            re.UNICODE | re.MULTILINE), _titleify),
        (re.compile(
            r'^(.+)\n.*',
            re.UNICODE), _titleify),
        (re.compile(
            r'^##(.+)##$',
            re.UNICODE | re.MULTILINE), _undertitleify),
    )
    for regex, cb in regexs:
        text = re.sub(regex, cb, text)
    # text = text.replace('\n', '</p><p>').replace('<p></p>', '<br />')

    text = text.replace('\r\n', '\n')
    text = text.replace('\n', '<br />')
    text = text.replace('\r', '')
    return u'''
<html><head><style type="text/css">
    p, li, pre, body {
        white-space: pre-wrap;
        font-family: "Nokia Pure Text";
        margin-top: 0px;
        margin-bottom: 0px;}
</style><body><p>%s</p></body></html>''' % text


def _unescape(text):
    def fixup(m):
        text = m.group(0)
        if text[:2] == "&#":
            # character reference
            try:
                if text[:3] == "&#x":
                    return unichr(int(text[3:-1], 16))
                else:
                    return unichr(int(text[2:-1]))
            except ValueError, e:
                print e
        else:
            # named entity
            try:
                text = unichr(
                    htmlentitydefs.name2codepoint[text[1:-1]])
            except KeyError, e:
                print e
        return text  # leave as is
    return re.sub("&#?\w+;", fixup, text)


def _uncolorize(text):
    text = _unescape(STRIPTAGS.sub('',
                     STRIPHEAD.sub('', text.replace('', '')
                                   .replace('\n<pre style="'
                                            + '-qt-paragraph-type:empty;'
                                            + ' margin-top:0px;'
                                            + ' margin-bottom:0px;'
                                            + ' margin-left:0px;'
                                            + ' margin-right:0px;'
                                            + ' -qt-block-indent:0;'
                                            + ' text-indent:0px;">'
                                            + '<br /></pre>', '\n')
                                   .replace('\n<p style="'
                                            + '-qt-paragraph-type:empty;'
                                            + ' margin-top:0px;'
                                            + ' margin-bottom:0px;'
                                            + ' margin-left:0px;'
                                            + ' margin-right:0px;'
                                            + ' -qt-block-indent:0;'
                                            + ' text-indent:0px;'
                                            + '"><br /></p>', '\n')
                                   .replace('<br />', '\n'))))
    return text.lstrip('\n')


def saveNote(filepath, data):

    if data == '':
        if os.path.exists(filepath):
            os.remove(filepath)

    data = _uncolorize(data)
    try:
        _title, _content = data.split('\n', 1)
    except ValueError:
        _title = data.split('\n', 1)[0]
        _content = ''

    base_path = NOTESPATH
    category = os.path.dirname(os.path.relpath(filepath, base_path))
    old_title = os.path.splitext(
        os.path.basename(os.path.relpath(filepath, base_path)))[0]

    if old_title and (_title != old_title):
        new_path = os.path.join(base_path,
                                category,
                                _getValidFilename(_title.strip()) + '.txt')

        if os.path.exists(new_path):
            raise StandardError('A note with same title already exist')

        os.rename(filepath, new_path)
        filepath = new_path

    with codecs.open(filepath, 'wb', 'utf_8') as fh:
        fh.write(_content)

    return filepath


def loadNote(path):
    path = os.path.join(NOTESPATH, path)
    with codecs.open(path, 'rb',
                     encoding='utf_8', errors='replace') as fh:
        try:
            text = fh.read()
            if text.find('\0') > 0:
                # Probably utf-16 ... decode it to utf-8
                # as qml didn t support it well'
                text = text.decode('utf-16')
            title = os.path.splitext(
                os.path.basename(path))[0]
            return _colorize((title + '\n' + text).replace('\r\n', '\n'))
        except:
            return 'gurk'


def listNotes(searchFilter):
    path = NOTESPATH
    notes = []
    for root, folders, filenames in os.walk(path):
            category = os.path.relpath(root, path)
            if category == u'.':
                category = u''
            if category != '.merge.sync':
                notes.extend([{'title': os.path.splitext(filename)[0],
                               'category': category,
                               'timestp':
                               os.stat(
                                   os.path.join(
                                       path,
                                       category,
                                       filename)).st_mtime,
                               'timestamp':
                               time.strftime('%x %X',
                                             time.localtime(
                                                 os.stat(
                                                     os.path.join(
                                                         path,
                                                         category,
                                                         filename)).st_mtime)),
                               'favorited': False,
                               'path': os.path.join(path, category, filename)}
                              for filename in filenames
                              if filename != '.index.sync'])

    notes.sort(key=lambda note: (not note['favorited'],
                                 note['category'],
                                 -int(note['timestp']),
                                 note['title']),
               reverse=False)

    return [note for note in notes
            if searchFilter.lower()
            in note['title'].lower()]


def reHighlight(text):
    return _colorize(_uncolorize(text))


def setSetting(section, option, value):
    global settings
    if section == 'WebDav':
        # Remove local sync index to prevent losing notes :
        if os.path.exists(os.path.join(NOTESPATH, '.index.sync')):
            os.remove(os.path.join(NOTESPATH, '.index.sync'))

    settings.set(section, option, value)
    return True


def getSetting(section, option):
    global settings
    return settings.get(section, option)


def getSyncStatus():
    global sync
    return sync.isRunning


def launchSync():
    global sync
    sync._wsync()
    return True


def createNote():
    inc = '1'
    path = os.path.join(NOTESPATH, 'Untitled %s.txt' % inc)
    while os.path.exists(path):
        inc = str(int(inc)+1)
        path = os.path.join(NOTESPATH, 'Untitled %s.txt' % inc)
    with file(path, 'w'):
        os.utime(path, (time.time(), time.time()))
    return 'Untitled %s.txt' % inc


def getCategories():
    categories = []
    for root, folders, filenames in os.walk(NOTESPATH):
            category = os.path.relpath(root, NOTESPATH)
            if category == u'.':
                category = u''
            if category != '.merge.sync':
                categories.append(category)
    return '\n'.join(categories)


def duplicate(path):
    import shutil
    dirname = os.path.dirname(path)
    filename = os.path.splitext(os.path.basename(path))[0] + ' 2.txt'
    dst = os.path.join(dirname, filename)
    shutil.copy2(path, dst)
    return dst


def rm(path):
    os.remove(path)


def setCategory(path, category):
    new_path = os.path.join(NOTESPATH, category, os.path.basename(path))
    if os.path.exists(new_path):
        raise StandardError('There is already a note with the same name'
                            ' in this category')

    if not os.path.exists(os.path.join(NOTESPATH,
                                       category)):
        os.mkdir(os.path.join(NOTESPATH, category))
    os.rename(path, new_path)

