#!/usr/bin/env python
# -*- coding: utf-8 -*-

# pylint: disable-msg=W0142,W0102,R0901,R0904,E0203,E1101,C0103
#
# Copyright 2008 German Aerospace Center (DLR)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


"""
The contained class extends the HTTPConnection class for WebDAV support.
"""


from httplib import HTTPConnection, CannotSendRequest, BadStatusLine, ResponseNotReady, IncompleteRead
from copy import copy
import base64   # for basic authentication
try:
    import hashlib
except ImportError: # for Python 2.4 compatibility
    import md5
    hashlib = md5
import mimetypes
import os       # file handling
import urllib
import types
import socket   # to "catch" socket.error
from threading import RLock
try:
    from uuid import uuid4
except ImportError: # for Python 2.4 compatibility
    from uuid_ import uuid4
from xml.parsers.expat import ExpatError

from davlib import DAV
from qp_xml import Parser

from webdav.WebdavResponse import MultiStatusResponse, ResponseFormatError
from webdav import Constants
from webdav.logger import getDefaultLogger


__version__ = "$LastChangedRevision$"


class Connection(DAV):
    """
    This class handles a connection to a WebDAV server.
    This class is used internally. Client code should prefer classes
    L{WebdavClient.ResourceStorer} and L{WebdavClient.CollectionStorer}.
    
    @author: Roland Betz
    """
    
    # Constants
    #  The following switch activates a workaround for the Tamino webdav server:
    #  Tamino expects URLs which are passed in a HTTP header to be Latin-1 encoded
    #  instead of Utf-8 encoded.
    #  Set this switch to zero in order to communicate with conformant servers.
    blockSize = 30000
    MaxRetries = 10
    
    def __init__(self, *args, **kwArgs):
        DAV.__init__(self, *args, **kwArgs)
        self.__authorizationInfo = None
        self.logger = getDefaultLogger()
        self.isConnectedToCatacomb = True
        self.serverTypeChecked = False
        self._lock = RLock()
         
    def _request(self, method, url, body=None, extra_hdrs={}):
        
        self._lock.acquire()
        try:
            # add the authorization header
            extraHeaders = copy(extra_hdrs)
            if self.__authorizationInfo:

                # update (digest) authorization data
                if hasattr(self.__authorizationInfo, "update"):
                    self.__authorizationInfo.update(method=method, uri=url)
                
                extraHeaders["AUTHORIZATION"] = self.__authorizationInfo.authorization
            
            # encode message parts
            body = _toUtf8(body)
            url = _urlEncode(url)
            for key, value in extraHeaders.items():
                extraHeaders[key] = _toUtf8(value)
                if key == "Destination": # copy/move header
                    if self.isConnectedToCatacomb:
                        extraHeaders[key] = _toUtf8(value.replace(Constants.SHARP, Constants.QUOTED_SHARP))
                        
                    else: # in case of TAMINO 4.4
                        extraHeaders[key] = _urlEncode(value)
            # pass message to httplib class
            for retry in range(0, Connection.MaxRetries):    # retry loop
                try:
                    self.logger.debug("REQUEST Send %s for %s" % (method, url))
                    self.logger.debug("REQUEST Body: " + repr(body))
                    for hdr in extraHeaders.items():
                        self.logger.debug("REQUEST Header: " + repr(hdr))
                    self.request(method, url, body, extraHeaders)
                    response = self.getresponse()
                    break  # no retry needed
                except (CannotSendRequest, socket.error, BadStatusLine, ResponseNotReady, IncompleteRead):
                    # Workaround, start: reconnect and retry...
                    self.logger.debug("Exception occurred! Retry... ", exc_info=True)
                    self.close()
                    try:
                        self.connect()
                    except (CannotSendRequest, socket.error, BadStatusLine, ResponseNotReady, IncompleteRead):
                        self.logger.debug("Connection failed.", exc_info=True)
                        raise WebdavError("Cannot perform request. Connection failed.")
                    if retry == Connection.MaxRetries - 1:
                        raise WebdavError("Cannot perform request.")
            return self.__evaluateResponse(method, response)
        finally:
            self._lock.release()
        
    def __evaluateResponse(self, method, response):
        """ Evaluates the response of the WebDAV server. """
        
        status, reason = response.status, response.reason
        self.logger.debug("Method: " + method + " Status %d: " % status + reason)
        
        if status >= Constants.CODE_LOWEST_ERROR:     # error has occured ?
            self.logger.debug("ERROR Response: " + response.read().strip())
            
            # identify authentication CODE_UNAUTHORIZED, throw appropriate exception
            if status == Constants.CODE_UNAUTHORIZED:
                raise AuthorizationError(reason, status, response.msg["www-authenticate"])
            
            response.close()
            raise WebdavError(reason, status)
        
        if status == Constants.CODE_MULTISTATUS:
            content = response.read()
            ## check for UTF-8 encoding
            try:
                response.root = Parser().parse(content)
            except ExpatError, error:
                errorMessage = "Invalid XML document has been returned.\nReason: '%s'" % str(error.args)
                raise WebdavError(errorMessage)
            try:
                response.msr = MultiStatusResponse(response.root)
            except ResponseFormatError:
                raise WebdavError("Invalid WebDAV response.")
            response.close()
            for status in unicode(response.msr).strip().split('\n'):
                self.logger.debug("RESPONSE (Multi-Status): " + status)
        elif method == 'LOCK' and status == Constants.CODE_SUCCEEDED:
            response.parse_lock_response()
            response.close()
        elif method != 'GET' and method != 'PUT':
            self.logger.debug("RESPONSE Body: " + response.read().strip())
            response.close()
        return response
        
    def addBasicAuthorization(self, user, password, realm=None):
        if user and len(user) > 0:
            self.__authorizationInfo = _BasicAuthenticationInfo(realm=realm, user=user, password=password)
                   
    def addDigestAuthorization(self, user, password, realm, qop, nonce, uri = None, method = None):
        if user and len(user) > 0:
            # username, realm, password, uri, method, qop are required
            self.__authorizationInfo = _DigestAuthenticationInfo(realm=realm, user=user, password=password, uri=uri, method=method, qop=qop, nonce=nonce)

    def putFile(self, path, srcfile, header={}):
        self._lock.acquire()
        try:
            # Assemble header
            try:
                size = os.path.getsize(srcfile.name)    
            except os.error, error:
                raise WebdavError("Cannot determine file size.\nReason: ''" % str(error.args))
            header["Content-length"] = str(size)
            
            contentType, contentEnc = mimetypes.guess_type(path)
            if contentType:
                header['Content-Type'] = contentType
            if contentEnc:
                header['Content-Encoding'] = contentEnc
            if self.__authorizationInfo:
                # update (digest) authorization data
                if hasattr(self.__authorizationInfo, "update"):
                    self.__authorizationInfo.update(method="PUT", uri=path)
                header["AUTHORIZATION"] = self.__authorizationInfo.authorization
                
            # send first request
            path = _urlEncode(path)
            try:
                HTTPConnection.request(self, 'PUT', path, "", header)
                self._blockCopySocket(srcfile, self, Connection.blockSize)
                srcfile.close()
                response = self.getresponse()
            except (CannotSendRequest, socket.error, BadStatusLine, ResponseNotReady):
                self.logger.debug("Exception occurred! Retry...", exc_info=True)
                raise WebdavError("Cannot perform request.")
            status, reason = (response.status, response.reason)
            self.logger.debug("Status %d: %s" % (status, reason))
            try:
                if status >= Constants.CODE_LOWEST_ERROR:     # error has occured ?
                    raise WebdavError(reason, status)
            finally:
                self.logger.debug("RESPONSE Body: " + response.read())
                response.close()        
            return response
        finally:
            self._lock.release()
                  
    def _blockCopySocket(self, source, toSocket, blockSize):
        transferredBytes = 0
        block = source.read(blockSize)
        while len(block):
            toSocket.send(block)
            self.logger.debug("Wrote %d bytes." % len(block))
            transferredBytes += len(block)
            block = source.read(blockSize)        
        self.logger.info("Transferred %d bytes." % transferredBytes)

    def __str__(self):
        return self.protocol + "://" + self.host + ':' + str(self.port)
        

class _BasicAuthenticationInfo(object):
    def __init__(self, **kwArgs):
        self.__dict__.update(kwArgs)
        self.cookie = base64.encodestring("%s:%s" % (self.user, self.password) ).strip()
        self.authorization = "Basic " + self.cookie
        self.password = None     # protect password security
        
class _DigestAuthenticationInfo(object):
    
    __nc = "0000000" # in hexadecimal without leading 0x
    
    def __init__(self, **kwArgs):

        self.__dict__.update(kwArgs)
        
        if self.qop is None:
            raise WebdavError("Digest without qop is not implemented.")
        if self.qop == "auth-int":
            raise WebdavError("Digest with qop-int is not implemented.")
    
    def update(self, **kwArgs):
        """ Update input data between requests"""
    
        self.__dict__.update(kwArgs)

    def _makeDigest(self):
        """ Creates the digest information. """
        
        # increment nonce count
        self._incrementNc()
        
        # username, realm, password, uri, method, qop are required
        
        a1 = "%s:%s:%s" % (self.user, self.realm, self.password)
        ha1 = hashlib.md5(a1).hexdigest()

        #qop == auth
        a2 = "%s:%s" % (self.method, self.uri)
        ha2 = hashlib.md5(a2).hexdigest()
        
        cnonce = str(uuid4())
        
        responseData = "%s:%s:%s:%s:%s:%s" % (ha1, self.nonce, _DigestAuthenticationInfo.__nc, cnonce, self.qop, ha2)
        digestResponse = hashlib.md5(responseData).hexdigest()
        
        authorization = "Digest username=\"%s\", realm=\"%s\", nonce=\"%s\", uri=\"%s\", algorithm=MD5, response=\"%s\", qop=auth, nc=%s, cnonce=\"%s\"" \
                        % (self.user, self.realm, self.nonce, self.uri, digestResponse, _DigestAuthenticationInfo.__nc, cnonce)
        return authorization
    
    authorization = property(_makeDigest)
    
    def _incrementNc(self):
        _DigestAuthenticationInfo.__nc = self._dec2nc(self._nc2dec() + 1)
    
    def _nc2dec(self):
        return int(_DigestAuthenticationInfo.__nc, 16)
    
    def _dec2nc(self, decimal):
        return hex(decimal)[2:].zfill(8)
    

class WebdavError(IOError):
    def __init__(self, reason, code=0):
        IOError.__init__(self, code)
        self.code = code
        self.reason = reason
    def __str__(self):
        return self.reason


class AuthorizationError(WebdavError):
    def __init__(self, reason, code, authHeader):
        WebdavError.__init__(self, reason, code)
        
        self.authType = authHeader.split(" ")[0]
        self.authInfo = authHeader


def _toUtf8(body):
    if not body is None:
        if type(body) == types.UnicodeType:
            body = body.encode('utf-8')
    return body


def _urlEncode(url):
    if type(url) == types.UnicodeType:
        url = url.encode('utf-8')
    return urllib.quote(url)
