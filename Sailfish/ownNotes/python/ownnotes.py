#!/usr/bin/python3
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
import os.path
import time
import re
import html.entities
from settings import Settings
from sync import Sync
import logger

INVALID_FILENAME_CHARS = '\/:*?"<>|'
STRIPTAGS = re.compile(r'<[^>]+>')
STRIPHEAD = re.compile("<head>.*?</head>", re.DOTALL)
EMPTYP = re.compile('<p style=\"-qt-paragraph-type:empty;.*(?=<p>)', re.DOTALL)

NOTESPATH = os.path.expanduser('~/.ownnotes/')

COLOR_TITLE = '#441144'
COLOR_LINK = '#115511'
COLOR_SUBTITLE = '#663366'

settings = Settings()
sync = Sync()

if not os.path.exists(NOTESPATH):
    os.makedirs(NOTESPATH)


def _getValidFilename(filepath):
    dirname, filename = os.path.dirname(filepath), os.path.basename(filepath)
    return os.path.join(dirname, ''.join(car for car in filename
                        if car not in INVALID_FILENAME_CHARS))


def setColors(title_color, subtitle_color, link_color):
    global COLOR_TITLE
    global COLOR_LINK
    global COLOR_SUBTITLE
    COLOR_TITLE = title_color
    COLOR_LINK = link_color
    COLOR_SUBTITLE = subtitle_color
    return True


def _strongify(group):
    return '<b>%s</b>' % group.group(0)


def _emify(group):
    return '<i>%s</i>' % group.group(0)


def _linkify(group):
    return '<font color="%s">%s</font>' % (COLOR_LINK,
                                           group.group(0))


def _titleify(group):
    return '<big><font color="%s">%s</font></big>' % (COLOR_TITLE,
                                                      group.group(0),)


def _undertitleify(group):
    return '<big><font color="%s">%s</font></big>' % (COLOR_SUBTITLE,
                                                      group.group(0))


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
            r'^#(.+)$',
            re.UNICODE | re.MULTILINE), _titleify),
        (re.compile(
            r'^##(.+)$',
            re.UNICODE | re.MULTILINE), _undertitleify),
    )

    text = text.replace('\r\n', '\n')
    text = text.replace('\r', '')

    for regex, cb in regexs:
        text = re.sub(regex, cb, text)

    text = text.split('\n', 1)
    text[0] = '<big><font color="%s">%s</font></big>' % (COLOR_TITLE,
                                                         text[0])
    text = '\n'.join(text).lstrip('\n')
    text = text.replace('\n', '<br />')

    return '''
<html><head><style type="text/css">
    p, li, pre, body {
        white-space: pre-wrap;
        margin-top: 0px;
        margin-bottom: 0px;}
</style></head><body><p>%s</p></body></html>''' % text


def _unescape(text):
    def fixup(m):
        text = m.group(0)
        if text[:2] == "&#":
            # character reference
            try:
                if text[:3] == "&#x":
                    return chr(int(text[3:-1], 16))
                else:
                    return chr(int(text[2:-1]))
            except ValueError as err:
                logger.Logger().logger.error(str(err))
        else:
            # named entity
            try:
                text = chr(
                    html.entities.name2codepoint[text[1:-1]])
            except KeyError as err:
                logger.Logger().logger.error(str(err))
        return text  # leave as is
    return re.sub("&#?\w+;", fixup, text)


def _uncolorize(text, strip=True):
    text = _unescape(STRIPTAGS.sub('',
                     STRIPHEAD.sub('',
                                   EMPTYP.sub('\n',
                                              text.replace('<br />',
                                                           '\n')))))
    return text.lstrip('\n')


def saveNote(filepath, data, colorized=True):
    global sync

    if data == '':
        if os.path.exists(filepath):
            os.remove(filepath)

    if colorized:
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
        index = 1
        new_path = os.path.join(base_path,
                                category,
                                _getValidFilename(_title.strip()) + '.txt')

        while os.path.exists(new_path):
            new_path = os.path.join(base_path,
                                    category,
                                    _getValidFilename(_title.strip())
                                    + str(index)
                                    + '.txt')
            index += 1

        try:
            os.rename(filepath, new_path)
        except OSError:
            logger.Logger().logger.error('Old didn t exists')

        filepath = new_path

    with open(filepath, 'w', encoding='utf-8') as fh:
        fh.write(_content)

    # Note pushing removed to avoid the app locking up
    # Perhaps this should be run in a different thread
    #try:
    #    relpath = os.path.join(category, _getValidFilename(_title.strip()) + '.txt')
    #    sync.push_note(relpath)
    #except Exception as err:
    #    logger.Logger().logger.error(str(err))

    return filepath


def loadNote(path, colorize=True):
    path = os.path.join(NOTESPATH, path)
    with open(path, 'r', encoding='utf-8') as fh:
        try:
            text = fh.read()
            title = os.path.splitext(
                os.path.basename(path))[0]
            if colorize:
                return _colorize((title + '\n' + text).replace('\r\n', '\n'))
            else:
                return (title + '\n' + text).replace('\r\n', '\n')
        except Exception as err:
            raise Exception('File IO Error %s' % (str(err)))
    raise Exception('File IO Error')

def loadPreview(path, colorize=False):
    path = os.path.join(NOTESPATH, path)
    with open(path, 'r', encoding='utf-8') as fh:
        try:
            text = fh.read(512)
            if colorize:
                return _colorize(text.replace('\r\n', '\n'))
            else:
                return text.replace('\r\n', '\n')
        except Exception as err:
            raise Exception('File IO Error %s' % (str(err)))
    raise Exception('File IO Error')


def nextNoteFile(current, offset=1):
    next = ''
    notesDetails = listNotes('')
    notes = [note['relpath'] for note in notesDetails]
    notes.append('')
    if current in notes:
        next = notes[(notes.index(current) + int(offset)) % len(notes)]
    return next

def listNotes(searchFilter):
    path = NOTESPATH
    notes = []
    for root, folders, filenames in os.walk(path):
        category = os.path.relpath(root, path)
        if category == '.':
            category = ''
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
                           'path': os.path.join(path, category, filename),
                           'relpath': os.path.join(category, filename)}
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
    return _colorize(_uncolorize(text, strip=False))


def setSetting(section, option, value):
    global settings
    if (section == 'WebDav') and (settings.get(section, option) != value):
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
    return sync._running


def launchSync():
    global sync
    return sync.sync()


def getCategoryFromPath(path):
    return os.path.dirname(
        os.path.relpath(path, NOTESPATH))


def getTitleFromPath(path):
    return os.path.basename(path)


def createNote():
    inc = '1'
    path = os.path.join(NOTESPATH, 'Untitled %s.txt' % inc)
    while os.path.exists(path):
        inc = str(int(inc) + 1)
        path = os.path.join(NOTESPATH, 'Untitled %s.txt' % inc)
    with open(path, 'w'):
        os.utime(path, (time.time(), time.time()))
    return os.path.join(NOTESPATH, 'Untitled %s.txt' % inc)


def getCategories():
    categories = ['']
    for root, folders, filenames in os.walk(NOTESPATH):
        category = os.path.relpath(root, NOTESPATH)
        if category == '.':
            category = ''
        elif filenames == []:
            continue  # Remove empty category
        elif (category != '.merge.sync') and (category not in categories):
            categories.append(category)
    categories.sort()
    return [{'name': acategory} for acategory in categories]


def duplicate(path):
    import shutil

    dirname = os.path.dirname(path)
    filename = os.path.splitext(os.path.basename(path))[0] + ' 2.txt'
    dst = os.path.join(dirname, filename)
    shutil.copy2(path, dst)
    return dst


def rm(path):
    os.remove(path)
    return True


def setCategory(path, category):

    if getCategoryFromPath(path) == category:
        return path

    new_path = os.path.join(NOTESPATH, category, os.path.basename(path))
    if os.path.exists(new_path):
        raise Exception('There is already a note with the same name'
                        ' in this category')

    if not os.path.exists(os.path.join(NOTESPATH,
                                       category)):
        os.mkdir(os.path.join(NOTESPATH, category))
    os.rename(path, new_path)
    return new_path


def publishAsPageToKhtCMS(text):
    return publishToKhtCMS(text, 'page')


def publishAsPostToKhtCMS(text):
    return publishToKhtCMS(text, 'blog')


def publishToKhtCMS(text, type):
    global settings
    from khtcms import KhtCMS
    data = _uncolorize(text)
    try:
        _title, _content = data.split('\n', 1)
    except ValueError:
        _title = data.split('\n', 1)[0]
        _content = ''

    KhtCMS().publish(type=type,
                     title=_title,
                     apikey=settings.get('KhtCms', 'apikey'),
                     url=settings.get('KhtCms', 'url'),
                     text=_content,
                     verify_ssl=settings.get('KhtCms', 'sslcheck'))
    return True


def publishToScriptogram(text):
    global settings
    from scriptogram import Scriptogram

    data = _uncolorize(text)
    try:
        _title, _content = data.split('\n', 1)
    except ValueError:
        _title = data.split('\n', 1)[0]
        _content = ''

    Scriptogram().publish(title=_title,
                          user_id=settings.get('Scriptogram', 'userid'),
                          text=_content)
    return True


def readChangeslog():
    text = ''
    changeLog = '/usr/share/ownNotes/datas/changelog.html'
    if os.path.isfile(changeLog):
        with open(changeLog) as fh:
            text = fh.read()
    return text

def get_last_sync_datetime():
    global sync
    return sync.get_last_sync_datetime()


if __name__ == '__init__':
    print(getCategoryFromPath(os.path.join(NOTESPATH, 'test', 'blabla.txt')))
