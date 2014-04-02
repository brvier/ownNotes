# The tinydav WebDAV client.
# Copyright (C) 2009  Manuel Hermann <manuel-hermann@gmx.net>
#
# This file is part of tinydav.
#
# tinydav is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""The tinydav WebDAV client."""
from __future__ import with_statement
import sys

PYTHON2_6 = (sys.version_info >= (2, 6))
PYTHON2_7 = (sys.version_info >= (2, 7))
PYTHON2 = ((2, 5) <= sys.version_info <= (3, 0))
PYTHON3 = (sys.version_info >= (3, 0))

from contextlib import closing
from email.header import Header
from functools import wraps, partial

if PYTHON2:
    from httplib import MULTI_STATUS, OK, CONFLICT, NO_CONTENT, UNAUTHORIZED
    from urllib import quote as urllib_quote
    from urllib import urlencode as urllib_urlencode
    from StringIO import StringIO
    import httplib
else:
    from http.client import MULTI_STATUS, OK, CONFLICT, NO_CONTENT
    from http.client import UNAUTHORIZED
    from io import BytesIO
    from io import StringIO
    from urllib.parse import quote as urllib_quote
    from urllib.parse import urlencode as urllib_urlencode
    import base64
    import http.client as httplib

from xml.etree.ElementTree import ElementTree, Element, SubElement, tostring

if PYTHON2_7 or PYTHON3:
    from xml.etree.ElementTree import ParseError
else:
    from xml.parsers.expat import ExpatError as ParseError

import hashlib

if PYTHON2:
    import urlparse
else:
    import urllib.parse as urlparse

from tinydav import creator, util
from tinydav.exception import HTTPError, HTTPUserError, HTTPServerError

__author__ = "Manuel Hermann <manuel-hermann@gmx.net>"
__license__ = "LGPL"
__version__ = "0.7.3"

__all__ = (
    "HTTPError", "HTTPUserError", "HTTPServerError",
    "HTTPClient", "WebDAVClient",
)

# RFC 2518, 9.8 Timeout Request Header
# The timeout value for TimeType "Second" MUST NOT be greater than 2^32-1.
MAX_TIMEOUT = 2**32-1

ACTIVELOCK = "./{DAV:}lockdiscovery/{DAV:}activelock"

# map with default ports mapped to http protocol
PROTOCOL = {
    80: "http",
    443: "https",
    8080: "http",
    8081: "http",
}

SCHEME_MAP = {
    "webdav": ("http", 80),
    "webdavs": ("https", 443),
    "http": ("http", 80),
    "https": ("https", 443),
}


default_header_encoding = "utf-8"
separate_query_sequences = True


# Responses
class HTTPResponse(int):
    """Result from HTTP request.

    An HTTPResponse object is a subclass of int. The int value of such an
    object is the HTTP status number from the response.

    This object has the following attributes:

    response -- The original httplib.HTTPResponse object.
    headers -- A dictionary with the received headers.
    content -- The content of the response as string.
    statusline -- The received HTTP status line. E.g. "HTTP/1.1 200 OK".

    """

    def __new__(cls, response):
        """Construct HTTPResponse.

        response -- The original httplib.HTTPResponse object.

        """
        return int.__new__(cls, response.status)

    def __init__(self, response):
        """Initialize the HTTPResponse.

        response -- The original httplib.HTTPResponse object. 

        """
        self.response = response
        self.headers = dict(response.getheaders())
        self.content = response.read()
        version = "HTTP/%s.%s" % tuple(str(response.version))
        self.statusline = "%s %d %s"\
                        % (version, response.status, response.reason)
        if self == UNAUTHORIZED:
            self._setauth()

    def __repr__(self):
        """Return representation."""
        if PYTHON2:
            return "<%s: %d>" % (self.__class__.__name__, self)
        else:
            return "<{0}: {1}>".format(self.__class__.__name__, self)

    def __str__(self):
        """Return string representation."""
        return self.statusline

    def _setauth(self):
        value = self.headers.get("www-authenticate", "")
        auth = util.parse_authenticate(value)
        for attrname in ("schema", "realm", "domain", "nonce", "opaque"):
            setattr(self, attrname, auth.get(attrname))
        stale = auth.get("stale")
        if stale is None:
            stale = "false"
        self.stale = (stale.lower() == "true")
        algorithm = auth.get("algorithm")
        if algorithm is None:
            algorithm = "MD5"
        self.algorithm = getattr(hashlib, algorithm.lower())


class WebDAVResponse(HTTPResponse):
    """Result from WebDAV request.

    A WebDAVResponse object is a subclass of int. The int value of such an
    object is the HTTP status number from the response.

    This object has the following attributes:

    response -- The original httplib.HTTPResponse object.
    headers -- A dictionary with the received headers.
    content -- The content of the response as string.
    statusline -- The received HTTP status line. E.g. "HTTP/1.1 200 OK".
    is_multistatus -- True, if the response's content is a multi-status
                      response.

    You can iterate over a WebDAVResponse object. If the received data was
    a multi-status response, the iterator will yield a MultiStatusResponse
    object per result. If it was no multi-status response, the iterator will
    just yield this WebDAVResponse object.

    The length of a WebDAVResponse object is 1, except for multi-status 
    responses. The length will then be the number of results in the
    multi-status.

    """
    def __init__(self, response):
        """Initialize the WebDAVResponse.

        response -- The original httplib.HTTPResponse object. 

        """
        super(WebDAVResponse, self).__init__(response)
        self._etree = ElementTree()
        # on XML parsing error set this to the raised exception
        self.parse_error = None
        self.is_multistatus = False
        if (self == MULTI_STATUS):
            self._set_multistatus()

    def __len__(self):
        """Return the number of responses in a multistatus response.

        When the response was no multistatus the return value is 1.

        """
        if self.is_multistatus:
            # RFC 2518, 12.9 multistatus XML Element
            # <!ELEMENT multistatus (response+, responsedescription?) >
            return len(self._etree.findall("./{DAV:}response"))
        return 1

    def __iter__(self):
        """Iterator over the response.

        Yield MultiStatusResponse instances for each response in a 207
        response.
        Yield self otherwise.

        """
        if self.is_multistatus:
            # RFC 2518, 12.9 multistatus XML Element
            # <!ELEMENT multistatus (response+, responsedescription?) >
            for response in self._etree.findall("./{DAV:}response"):
                yield MultiStatusResponse(response)
        else:
            yield self

    def _parse_xml_content(self):
        """Parse the XML content.

        If the response content cannot be parsed as XML content, 
        <root><empty/></root> will be taken as content instead.

        """
        try:
            if PYTHON2:
                parse_me = StringIO(self.content)
            else:
                parse_me = BytesIO(self.content)
            self._etree.parse(parse_me)
        except ParseError:
            # get the exception object this way to be compatible with Python
            # versions 2.5 up to 3.x
            self.parse_error = sys.exc_info()[1]
            # don't fail on further processing
            self._etree.parse(StringIO("<root><empty/></root>"))

    def _set_multistatus(self):
        """Set this response to a multistatus response."""
        self.is_multistatus = True
        self._parse_xml_content()


class WebDAVLockResponse(WebDAVResponse):
    """Result from WebDAV LOCK request.

    A WebDAVLockResponse object is a subclass of WebDAVResponse which is a 
    subclass of int. The int value of such an object is the HTTP status number
    from the response.

    This object has the following attributes:

    response -- The original httplib.HTTPResponse object.
    headers -- A dictionary with the received headers.
    content -- The content of the response as string.
    statusline -- The received HTTP status line. E.g. "HTTP/1.1 200 OK".
    is_multistatus -- True, if the response's content is a multi-status
                      response.
    lockscope -- Specifies whether a lock is an exclusive lock, or a
                 shared lock.
    locktype -- Specifies the access type of a lock (which is always write).
    depth -- The value of the Depth header.
    owner --  The principal taking out this lock.
    timeout -- The timeout associated with this lock
    locktoken -- The lock token associated with this lock.

    You can iterate over a WebDAVLockResponse object. If the received data was
    a multi-status response, the iterator will yield a MultiStatusResponse
    object per result. If it was no multi-status response, the iterator will
    just yield this WebDAVLockResponse object.

    The length of a WebDAVLockResponse object is 1, except for multi-status 
    responses. The length will then be the number of results in the
    multi-status.

    You can use this object to make conditional requests. For this, the context
    manager protocol is implemented:

    >>> lock = dav.lock("somewhere")
    >>> with lock:
    >>>    dav.put("somwhere", <something>)

    The above example will make a tagged PUT request. For untagged requests do:

    >>> lock = dav.lock("somewhere")
    >>> with lock(False):
    >>>    dav.put("somwhere", <something>)

    """
    def __new__(cls, client, uri, response):
        """Construct WebDAVLockResponse.
        
        client -- HTTPClient instance or one of its subclasses.
        uri -- The called uri.
        response --The original httplib.HTTPResponse object. 

        """
        return WebDAVResponse.__new__(cls, response)

    def __init__(self, client, uri, response):
        """Initialize the WebDAVLockResponse.

        client -- HTTPClient instance or one of its subclasses.
        uri -- The called uri.
        response -- The original httplib.HTTPResponse object.

        """
        super(WebDAVLockResponse, self).__init__(response)
        self._client = None
        self._uri = None
        self._locktype = None
        self._lockscope = None
        self._depth = None
        self._owner = None
        self._timeout = None
        self._locktokens = None
        self._previous_if = None
        self._tagged = True
        self._tag = None
        # RFC 2518, 8.10.7 Status Codes
        # 200 (OK) - The lock request succeeded and the value of the
        # lockdiscovery property is included in the body.
        if self == OK:
            self._parse_xml_content()
            self._client = client
            self._uri = uri
            self._tag = util.make_absolute(self._client, uri)
        # RFC 2518, 8.10.4 Depth and Locking
        # If the lock cannot be granted to all resources, a 409 (Conflict)
        # status code MUST be returned with a response entity body
        # containing a multistatus XML element describing which resource(s)
        # prevented the lock from being granted.
        elif self == CONFLICT:
            self._set_multistatus()

    def __repr__(self):
        """Return representation."""
        return "<%s: <%s> %d>" % (self.__class__.__name__, self._tag, self)

    def __call__(self, tagged=True):
        """Configure this lock to use tagged header or not.

        tagged -- True, if the If header should contain a tagged list.
                  False, if the If header should contain a no-tag-list.
                  Default is True.

        """
        self._tagged = tagged
        return self

    def __enter__(self):
        """Use the lock on requests on the returned prepare WebDAVClient."""
        if self.locktokens:
            # RFC 2518, 9.4 If Header
            # If = "If" ":" ( 1*No-tag-list | 1*Tagged-list)
            # No-tag-list = List
            # Tagged-list = Resource 1*List
            # Resource = Coded-URL
            # List = "(" 1*(["Not"](State-token | "[" entity-tag "]")) ")"
            # State-token = Coded-URL
            # Coded-URL = "<" absoluteURI ">"
            self._previous_if = self._client.headers.get("If")
            tokens = "".join("<%s>" % token for token in self.locktokens)
            if self._tagged:
                if_value = "<%s> (%s)" % (self._tag, tokens)
            else:
                if_value = "(%s)" % tokens
                self._tagged = True
            self._client.headers["If"] = if_value
        return self._client

    def __exit__(self, exc, exctype, exctb):
        """Remove If statement in WebDAVClient."""
        if "If" in self._client.headers:
            if self._previous_if is not None:
                self._client.headers["If"] = self._previous_if
                self._previous_if = None
            else:
                del self._client.headers["If"]

    @property
    def lockscope(self):
        """Return the lockscope as ElementTree element."""
        if self._lockscope is None:
            # RFC 2518, 12.7 lockscope XML Element
            # <!ELEMENT lockscope (exclusive | shared) >
            # RFC 2518, 12.7.1 exclusive XML Element
            # <!ELEMENT exclusive EMPTY >
            # RFC 2518, 12.7.2 shared XML Element
            # <!ELEMENT shared EMPTY >
            scope = ACTIVELOCK + "/{DAV:}lockscope/*"
            self._lockscope = self._etree.find(scope)
        return self._lockscope

    @property
    def locktype(self):
        """Return the type of this lock."""
        if self._locktype is None:
            # RFC 2518, 12.8 locktype XML Element
            # <!ELEMENT locktype (write) >
            locktype = ACTIVELOCK + "/{DAV:}locktype/*"
            self._locktype = self._etree.find(locktype)
        return self._locktype

    @property
    def depth(self):
        """Return the applied depth."""
        if self._depth is None:
            # RFC 2518, 12.1.1 depth XML Element
            # <!ELEMENT depth (#PCDATA) >
            depth = ACTIVELOCK + "/{DAV:}depth"
            self._depth = self._etree.findtext(depth)
        return self._depth

    @property
    def owner(self):
        """Return the owner ElementTree element or None, if there's no owner."""
        if self._owner is None:
            # RFC 2518, 12.10 owner XML Element
            # <!ELEMENT owner ANY>
            owner = ACTIVELOCK + "/{DAV:}owner"
            self._owner = self._etree.find(owner)
        return self._owner

    @property
    def timeout(self):
        """Return the timeout of this lock or None, if not available."""
        if self._timeout is None:
            # RFC 2518, 12.1.3 timeout XML Element
            # <!ELEMENT timeout (#PCDATA) >
            timeout = ACTIVELOCK + "/{DAV:}timeout"
            self._timeout = self._etree.findtext(timeout).strip()
        return self._timeout

    @property
    def locktokens(self):
        """Return the locktokens for this lock."""
        if self._locktokens is None:
            # RFC 2518, 12.1.2 locktoken XML Element
            # <!ELEMENT locktoken (href+) >
            token = ACTIVELOCK + "/{DAV:}locktoken/{DAV:}href"
            self._locktokens = [t.text.strip()
                                for t in self._etree.findall(token)]
        return self._locktokens


class MultiStatusResponse(int):
    """Wrapper for multistatus responses.

    A MultiStatusResponse object is a subclass of int. The int value of such an
    object is the HTTP status number from the response.

    Furthermore this object implements the dictionary interface. Through it 
    you can access all properties that the resource has.

    This object has the following attributes:

    statusline -- The received HTTP status line. E.g. "HTTP/1.1 200 OK".
    href -- The HREF of the resource this status is for.
    namespaces -- A frozenset with all the XML namespaces that the underlying
                  XML structure had.

    """
    def __new__(cls, response):
        """Create instance with status code as int value."""
        # RFC 2518, 12.9.1 response XML Element
        # <!ELEMENT response (href, ((href*, status)|(propstat+)),
        # responsedescription?) >
        statusline = response.findtext("{DAV:}propstat/{DAV:}status")
        status = int(statusline.split()[1])
        return int.__new__(cls, status)

    def __init__(self, response):
        """Initialize the MultiStatusResponse.

        response -- ElementTree element: response-tag.

        """
        self.response = response
        self._href = None
        self._statusline = None
        self._namespaces = None

    def __repr__(self):
        """Return representation string."""
        return "<%s: %d>" % (self.__class__.__name__, self)

    def __getitem__(self, name):
        """Return requested property as ElementTree element.

        name -- Name of the property with namespace. No namespace needed for
                DAV properties.

        """
        # check, whether it's a default DAV property name
        if not name.startswith("{"):
            name = "{DAV:}%s" % name
        # RFC 2518, 12.9.1.1 propstat XML Element
        # <!ELEMENT propstat (prop, status, responsedescription?) >
        prop = self.response.find("{DAV:}propstat/{DAV:}prop/%s" % name)
        if prop is None:
            raise KeyError(name)
        return prop

    if PYTHON2:
        def __iter__(self):
            """Iterator over propertynames with their namespaces."""
            return self.iterkeys()
    else:
        def __iter__(self):
            """Iterator over propertynames with their namespaces."""
            return self.keys()

    if PYTHON2:
        def keys(self):
            """Return list of propertynames with their namespaces.

            No namespaces for DAV properties.

            """
            return list(self.iterkeys())

        def iterkeys(self, cut_dav_ns=True):
            """Iterate over propertynames with their namespaces.

            cut_dav_ns -- No namespaces for DAV properties when this is True.

            """
            for (tagname, value) in self.iteritems(cut_dav_ns):
                yield tagname
    else:
        def keys(self, cut_dav_ns=True):
            """Iterate over propertynames with their namespaces.

            cut_dav_ns -- No namespaces for DAV properties when this is True.

            """
            for (tagname, value) in self.items(cut_dav_ns):
                yield tagname

    def items(self):
        """Return list of 2-tuples with propertyname and ElementTree element."""
        return list(self.iteritems())

    def iteritems(self, cut_dav_ns=True):
        """Iterate list of 2-tuples with propertyname and ElementTree element.

        cut_dav_ns -- No namespaces for DAV properties when this is True.

        """
        # RFC 2518, 12.11 prop XML element
        # <!ELEMENT prop ANY>
        props = self.response.findall("{DAV:}propstat/{DAV:}prop/*")
        for prop in props:
            tagname = prop.tag
            if cut_dav_ns and tagname.startswith("{DAV:}"):
                tagname = tagname[6:]
            yield (tagname, prop)

    if PYTHON3:
        items = iteritems
        del iteritems

    def get(self, key, default=None, namespace=None):
        """Return value for requested property.

        key -- Property name with namespace. Namespace may be omitted, when
               namespace-argument is given, or Namespace is DAV:
        default -- Return this value when key does not exist.
        namespace -- The namespace in which the property lives in. Must be
                     given, when the key value has no namespace defined and
                     the namespace ist not DAV:.

        """
        if namespace:
            key = "{%s}%s" % (namespace, key)
        try:
            return self[key]
        except KeyError:
            return default

    @property
    def statusline(self):
        """Return the status line for this response."""
        if self._statusline is None:
            # RFC 2518, 12.9.1.2 status XML Element
            # <!ELEMENT status (#PCDATA) >
            statustag = self.response.findtext("{DAV:}propstat/{DAV:}status")
            self._statusline = statustag
        return self._statusline

    @property
    def href(self):
        """Return the href for this response."""
        if self._href is None:
            # RFC 2518, 12.3 href XML Element
            # <!ELEMENT href (#PCDATA)>
            self._href = self.response.findtext("{DAV:}href")
        return self._href

    if PYTHON2:
        @property
        def namespaces(self):
            """Return frozenset of namespaces."""
            if self._namespaces is None:
                self._namespaces = frozenset(util.extract_namespace(key)
                                             for key in self.iterkeys(False)
                                             if util.extract_namespace(key))
            return self._namespaces
    else:
        @property
        def namespaces(self):
            """Return frozenset of namespaces."""
            if self._namespaces is None:
                self._namespaces = frozenset(util.extract_namespace(key)
                                             for key in self.keys(False)
                                             if util.extract_namespace(key))
            return self._namespaces


# Clients
class HTTPClient(object):
    """Mini HTTP client.

    This object has the following attributes:

    host -- Given host on initialization.
    port -- Given port on initialization.
    protocol -- Used protocol. Either chosen by the port number or taken
                from given value in initialization.
    headers -- Dictionary with headers to send with every request.
    cookie -- If set with setcookie: the given object.
    locks -- Mapping with locks.

    """

    ResponseType = HTTPResponse

    @classmethod
    def fromurl(cls, uri, **kwargs):
        """Construct HTTPClient instance from given uri."""
        parsed = urlparse.urlparse(uri)

        (protocol, port) = SCHEME_MAP[parsed.scheme]
        if parsed.port:
            port = parsed.port

        self = cls(parsed.hostname, port=port, protocol=protocol, **kwargs)
        if parsed.username:
            self.setbasicauth(parsed.username, parsed.password)
        return self

    def __init__(self, host, port=80, protocol=None, strict=False,
                 timeout=None, source_address=None):
        """Initialize the WebDAV client.

        host -- WebDAV server host.
        port -- WebDAV server port.
        protocol -- Override protocol name. Is either 'http' or 'https'. If
                    not given, the protocol will be chosen by the port number
                    automatically:
                        80   -> http
                        443  -> https
                        8080 -> http
                        8081 -> http
                    Default port is 'http'.
        strict -- When True, raise BadStatusLine if the status line can't be
                  parsed as a valid HTTP/1.0 or 1.1 status line (see Python
                  doc for httplib).
        timeout -- Operations will timeout after that many seconds. Else the
                   global default timeout setting is used (see Python doc for
                   httplib). This argument is available since Python 2.6. It
                   won't have any effect in previous version.
        source_address -- A tuple of (host, port) to use as the source address
                          the HTTP connection is made from (see Python doc for
                          httplib). This argument is available since
                          Python 2.7. It won't have any effect in previous
                          versions.

        """
        assert isinstance(port, int)
        assert protocol in (None, "http", "https")
        self.host = host
        self.port = port
        if protocol is None:
            self.protocol = PROTOCOL.get(port, "http")
        else:
            self.protocol = protocol
        self.strict = strict
        self.timeout = timeout
        self.source_address = source_address
        if PYTHON2:
            self.key_file = None
            self.cert_file = None
        else:
            self.context = None
        self.headers = dict()
        self.cookie = None
        self._do_digest_auth = False

    def _getconnection(self):
        """Return HTTP(S)Connection object depending on set protocol."""
        args = (self.host, self.port,)
        kwargs = dict(strict=self.strict)
        if PYTHON2_6:
            kwargs["timeout"] = self.timeout
        if PYTHON2_7:
            kwargs["source_address"] = self.source_address
        if self.protocol == "http":
            return httplib.HTTPConnection(*args, **kwargs)
        # setup HTTPS
        if PYTHON2:
            kwargs["key_file"] = self.key_file
            kwargs["cert_file"] = self.cert_file
        else:
            kwargs["context"] = self.context
        return httplib.HTTPSConnection(*args, **kwargs)

    def _request(self, method, uri, content=None, headers=None):
        """Make request and return response.

        method -- Request method.
        uri -- URI the request is for.
        content -- The content of the request. May be None.
        headers -- If given, a mapping with additonal headers to send.

        """
        if not uri.startswith("/"):
            uri = "/%s" % uri

        headers = dict() if (headers is None) else headers

        # handle cookies, if necessary
        if self.cookie is not None:
            fake_request = util.FakeHTTPRequest(self, uri, headers)
            self.cookie.add_cookie_header(fake_request)

        con = self._getconnection()
        with closing(con):
            con.request(method, uri, content, headers)
            response = self.ResponseType(con.getresponse())
            if 400 <= response < 500:
                response = HTTPUserError(response)
            elif 500 <= response < 600:
                response = HTTPServerError(response)

        if self.cookie is not None:
            # Get response object suitable for cookielib
            cookie_response = util.get_cookie_response(response)
            self.cookie.extract_cookies(cookie_response, fake_request)

        if isinstance(response, HTTPError):
            raise response
        return response

    def _prepare(self, uri, headers, query=None):
        """Return 2-tuple with prepared version of uri and headers.

        The headers will contain the authorization headers, if given.

        uri -- URI the request is for.
        headers -- Mapping with additional headers to send. Unicode values that
                   are no ASCII will be MIME-encoded with UTF-8. Set 
                   tinydav.default_header_encoding to another encoding, if
                   UTF-8 doesn't suit you.
        query -- Mapping with key/value-pairs to be added as query to the URI.

        """
        uri = urllib_quote(uri)
        # collect headers
        sendheaders = dict(self.headers)
        if headers:
            sendheaders.update(headers)
        for (key, value) in sendheaders.items():
            try:
                unicode(value).encode("ascii")
            except UnicodeError:
                value = str(Header(value, default_header_encoding))
            sendheaders[key] = value
        # construct query string
        if query:
            querystr = urllib_urlencode(query, doseq=separate_query_sequences)
            uri = "%s?%s" % (uri, querystr)
        return (uri, sendheaders)

    if PYTHON2:
        def setbasicauth(self, user, password):
            """Set authorization header for basic auth.

            user -- Username
            password -- Password for user.

            """
            # RFC 2068, 11.1 Basic Authentication Scheme
            # basic-credentials = "Basic" SP basic-cookie
            # basic-cookie   = <base64 [7] encoding of user-pass,
            # except not limited to 76 char/line>
            # user-pass   = userid ":" password
            # userid      = *<TEXT excluding ":">
            # password    = *TEXT
            userpw = "%s:%s" % (user, password)
            auth = userpw.encode("base64").rstrip()
            self.headers["Authorization"] = "Basic %s" % auth
    else:
        def setbasicauth(self, user, password,
                         b64encoder=base64.standard_b64encode):
            """Set authorization header for basic auth.

            user -- Username as bytes string.
            password -- Password for user as bytes.
            encoder -- Base64 encoder function. Default is the standard 
                       encoder. Should not be changed.

            """
            # RFC 2068, 11.1 Basic Authentication Scheme
            # basic-credentials = "Basic" SP basic-cookie
            # basic-cookie   = <base64 [7] encoding of user-pass,
            # except not limited to 76 char/line>
            # user-pass   = userid ":" password
            # userid      = *<TEXT excluding ":">
            # password    = *TEXT
            userpw = user + bytes(":", "ascii") + password
            auth = b64encoder(userpw).decode("ascii")
            self.headers["Authorization"] = "Basic {0}".format(auth)

    def setcookie(self, cookie):
        """Set cookie class to be used in requests.

        cookie -- Cookie class from cookielib.

        """
        self.cookie = cookie

    if PYTHON2:
        def setssl(self, key_file=None, cert_file=None):
            """Set SSL key file and/or certificate chain file for HTTPS.

            Calling this method has the side effect of setting the protocol to
            https.

            key_file -- The name of a PEM formatted file that contains your
                        private key.
            cert_file -- PEM formatted certificate chain file (see Python doc
                         for httplib).
            """
            self.key_file = key_file
            self.cert_file = cert_file
            if any((key_file, cert_file)):
                self.protocol = "https"
    else:
        def setssl(self, context):
            """Set SSLContext for this connection.

            Calling this method has the side effect of setting the protocol to
            https.

            context -- ssl.SSLContext instance describing the various SSL
                       options.

            """
            self.protocol = "https"
            self.context = context

    def options(self, uri, headers=None):
        """Make OPTIONS request and return status.

        uri -- URI of the request.
        headers -- Optional mapping with headers to send.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        return self._request("OPTIONS", uri, None, headers)

    def get(self, uri, headers=None, query=None):
        """Make GET request and return status.

        uri -- URI of the request.
        headers -- Optional mapping with headers to send.
        query -- Mapping with key/value-pairs to be added as query to the URI.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers, query)
        return self._request("GET", uri, None, headers)

    def head(self, uri, headers=None, query=None):
        """Make HEAD request and return status.

        uri -- URI of the request.
        headers -- Optional mapping with headers to send.
        query -- Mapping with key/value-pairs to be added as query to the URI.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers, query)
        return self._request("HEAD", uri, None, headers)

    def post(self, uri, content="", headers=None, query=None,
             as_multipart=False, encoding="ascii", with_filenames=False):
        """Make POST request and return HTTPResponse.

        uri -- Path to post data to.
        content -- File descriptor, string or dict with content to POST. If it
                   is a dict, the dict contents will be posted as content type
                   application/x-www-form-urlencoded.
        headers -- If given, must be a mapping with headers to set.
        query -- Mapping with key/value-pairs to be added as query to the URI.
        as_multipart -- Send post data as multipart/form-data. content must be
                        a dict, then. If content is not a dict, then this 
                        argument will be ignored. The values of the dict may be
                        a subclass of email.mime.base.MIMEBase, which will be
                        attached to the multipart as is, a 2-tuple containing
                        the actual value (or file-like object) and an encoding
                        for this value (or the content-type in case of a 
                        file-like object).
        encoding -- Send multipart content with this encoding. Default is
                    ASCII.
        with_filenames -- If True, a multipart's files will be sent with the
                          filename paramenter set. Default is False.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers, query)
        if isinstance(content, dict):
            if as_multipart:
                (multihead, content) = util.make_multipart(content,
                                                           encoding,
                                                           with_filenames)
                headers.update(multihead)
            else:
                headers["content-type"] = "application/x-www-form-urlencoded"
                content = urllib_urlencode(content)
        if hasattr(content, "read") and not PYTHON2_6:
            # python 2.5 httlib cannot handle file-like objects
            content = content.read()
        return self._request("POST", uri, content, headers)

    def put(self, uri, fileobject, content_type="application/octet-stream",
            headers=None):
        """Make PUT request and return status.

        uri -- Path for PUT.
        fileobject -- File-like object or string with content to PUT.
        content_type -- The content-type of the file. Default value is
                        application/octet-stream.
        headers -- If given, must be a dict with headers to send.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        headers["content-type"] = content_type
        # use 2.6 feature, if running under this version
        data = fileobject if PYTHON2_6 else fileobject.read()
        return self._request("PUT", uri, data, headers)

    def delete(self, uri, content="", headers=None):
        """Make DELETE request and return HTTPResponse.

        uri -- Path to post data to.
        content -- File descriptor or string with content.
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        return self._request("DELETE", uri, content, headers)

    def trace(self, uri, maxforwards=None, via=None, headers=None):
        """Make TRACE request and return HTTPResponse.

        uri -- Path to post data to.
        maxforwards -- Number of maximum forwards. May be None.
        via -- If given, an iterable containing each station in the form
               stated in RFC2616, section 14.45.
        headers -- If given, must be a mapping with headers to set.

        Raise ValueError, if maxforward is not an int or convertable to
        an int.
        Raise TypeError, if via is not an iterable of string.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        if maxforwards is not None:
            # RFC 2068, 14.31 Max-Forwards
            # Max-Forwards   = "Max-Forwards" ":" 1*DIGIT
            int(maxforwards)
            headers["Max-Forwards"] = str(maxforwards)
        # RFC 2068, 14.44 Via
        if via:
            headers["Via"] = ", ".join(via)
        return self._request("TRACE", uri, None, headers)

    def connect(self, uri, headers=None):
        """Make CONNECT request and return HTTPResponse.

        uri -- Path to post data to.
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        return self._request("CONNECT", uri, None, headers)


class CoreWebDAVClient(HTTPClient):
    """Basic WebDAVClient specified in RFC 2518.

    This object has the following attributes:

    host -- Given host on initialization.
    port -- Given port on initialization.
    protocol -- Used protocol. Either chosen by the port number or taken
                from given value in initialization.
    headers -- Dictionary with headers to send with every request.
    cookie -- If set with setcookie: the given object.
    locks -- Dictionary containing all active locks, mapped by tag -> Lock.

    """

    ResponseType = WebDAVResponse

    def __init__(self, host, port=80, protocol=None):
        """Initialize the WebDAV client.

        host -- WebDAV server host.
        port -- WebDAV server port.
        protocol -- Override protocol name. Is either 'http' or 'https'. If
                    not given, the protocol will be chosen by the port number
                    automatically:
                        80   -> http
                        443  -> https
                        8080 -> http
                        8081 -> http
                    Default port is 'http'.

        """
        super(CoreWebDAVClient, self).__init__(host, port, protocol)
        self.locks = dict()

    def _preparecopymove(self, source, destination, depth, overwrite, headers):
        """Return prepared for copy/move request version of uri and headers."""
        # RFC 2518, 8.8.3 COPY for Collections
        # A client may submit a Depth header on a COPY on a collection with a
        # value of "0" or "infinity".
        depth = util.get_depth(depth, ("0", "infinity"))
        headers = dict() if (headers is None) else headers
        (source, headers) = self._prepare(source, headers)
        # RFC 2518, 8.8 COPY Method
        # The Destination header MUST be present.
        # RFC 2518, 8.9 MOVE Method
        # Consequently, the Destination header MUST be present on all MOVE
        # methods and MUST follow all COPY requirements for the COPY part of
        # the MOVE method.
        # RFC 2518, 9.3 Destination Header
        # Destination = "Destination" ":" absoluteURI
        headers["Destination"] = util.make_absolute(self, destination)
        # RFC 2518, 8.8.3 COPY for Collections
        # A client may submit a Depth header on a COPY on a collection with
        # a value of "0" or "infinity".
        # RFC 2518, 8.9.2 MOVE for Collections
        if source.endswith("/"):
            headers["Depth"] = depth
        # RFC 2518, 8.8.4 COPY and the Overwrite Header
        #           8.9.3 MOVE and the Overwrite Header
        # If a resource exists at the destination and the Overwrite header is
        # "T" then prior to performing the copy the server MUST perform a
        # DELETE with "Depth: infinity" on the destination resource.  If the
        # Overwrite header is set to "F" then the operation will fail.
        if overwrite is not None:
            headers["Overwrite"] = "T" if overwrite else "F"
        return (source, headers)

    def mkcol(self, uri, headers=None):
        """Make MKCOL request and return status.

        uri -- Path to create.
        headers -- If given, must be a dict with headers to send.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        return self._request("MKCOL", uri, None, headers)

    def propfind(self, uri, depth=0, names=False,
                 properties=None, include=None, namespaces=None,
                 headers=None):
        """Make PROPFIND request and return status.

        uri -- Path for PROPFIND.
        depth -- Depth for PROFIND request. Default is zero.
        names -- If True, only the available namespace names are returned.
        properties -- If given, an iterable with all requested properties is
                      expected.
        include -- If properties is not given, then additional properties can
                   be requested with this argument.
        namespaces -- Mapping with namespaces for given properties, if needed.
        headers -- If given, must be a dict with headers to send.

        Raise ValueError, if illegal depth was given or if properties and
        include arguments were given.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        namespaces = dict() if (namespaces is None) else namespaces
        # RFC 2518, 8.1 PROPFIND
        # A client may submit a Depth header with a value of "0", "1", or
        # "infinity" with a PROPFIND on a collection resource with internal
        # member URIs.
        depth = util.get_depth(depth)
        # check mutually exclusive arguments
        if all([properties, include]):
            raise ValueError("properties and include are mutually exclusive")
        (uri, headers) = self._prepare(uri, headers)
        # additional headers needed for PROPFIND
        headers["Depth"] = depth
        headers["Content-Type"] = "application/xml"
        content = creator.create_propfind(names, properties,
                                          include, namespaces)
        return self._request("PROPFIND", uri, content, headers)

    def proppatch(self, uri, setprops=None, delprops=None,
                  namespaces=None, headers=None):
        """Make PROPPATCH request and return status.

        uri -- Path to resource to set properties.
        setprops -- Mapping with properties to set.
        delprops -- Iterable with properties to remove.
        namespaces -- dict with namespaces: name -> URI.
        headers -- If given, must be a dict with headers to send.

        Either setprops or delprops or both of them must be given, else
        ValueError will be risen.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        # RFC 2518, 12.13 propertyupdate XML element
        # <!ELEMENT propertyupdate (remove | set)+ >
        if not any((setprops, delprops)):
            raise ValueError("setprops and/or delprops must be given")
        (uri, headers) = self._prepare(uri, headers)
        # additional header for proppatch
        headers["Content-Type"] = "application/xml"
        content = creator.create_proppatch(setprops, delprops, namespaces)
        return self._request("PROPPATCH", uri, content, headers)

    def delete(self, uri, headers=None):
        """Make DELETE request and return WebDAVResponse.

        uri -- Path of resource or collection to delete.
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        headers = dict() if (headers is None) else headers
        if uri.endswith("/"):
            # RFC 2518, 8.6.2 DELETE for Collections
            # A client MUST NOT submit a Depth header with a DELETE on a
            # collection with any value but infinity.
            headers["Depth"] = "infinity"
        return super(CoreWebDAVClient, self).delete(uri, headers=headers)

    def copy(self, source, destination, depth="infinity",
             overwrite=None, headers=None):
        """Make COPY request and return WebDAVResponse.

        source -- Path of resource to copy.
        destination -- Path of destination to copy source to.
        depth -- Either 0 or "infinity". Default is the latter.
        overwrite -- If not None, then a boolean indicating whether the
                     Overwrite header ist set to "T" (True) or "F" (False).
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (source, headers) = self._preparecopymove(source, destination, depth,
                                                  overwrite, headers)
        return self._request("COPY", source, None, headers)

    def move(self, source, destination, depth="infinity",
             overwrite=None, headers=None):
        """Make MOVE request and return WebDAVResponse.

        source -- Path of resource to move.
        destination -- Path of destination to move source to.
        depth -- Either 0 or "infinity". Default is the latter.
        overwrite -- If not None, then a boolean indicating whether the
                     Overwrite header ist set to "T" (True) or "F" (False).
        headers -- If given, must be a mapping with headers to set.

        Raise ValueError, if an illegal depth was given.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        # RFC 2518, 8.9.2 MOVE for Collections
        # A client MUST NOT submit a Depth header on a MOVE on a collection
        # with any value but "infinity".
        if source.endswith("/") and (depth != "infinity"):
            raise ValueError("depth must be infinity when moving collections")
        (source, headers) = self._preparecopymove(source, destination, depth,
                                                  overwrite, headers)
        return self._request("MOVE", source, None, headers)

    def lock(self, uri, scope="exclusive", type_="write", owner=None,
             timeout=None, depth=None, headers=None):
        """Make LOCK request and return DAVLock instance.

        uri -- Resource to get lock on.
        scope -- Lock scope: One of "exclusive" (default) or "shared".
        type_ -- Lock type: "write" (default) only. Any other value allowed by
                 this library.
        owner -- Content of owner element. May be None, a string or an
                 ElementTree element.
        timeout -- Value for the timeout header. Either "infinite" or a number
                   representing the seconds (not greater than 2^32 - 1).
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        (uri, headers) = self._prepare(uri, headers)
        # RFC 2518, 9.8 Timeout Request Header
        # TimeOut = "Timeout" ":" 1#TimeType
        # TimeType = ("Second-" DAVTimeOutVal | "Infinite" | Other)
        # DAVTimeOutVal = 1*digit
        # Other = "Extend" field-value   ; See section 4.2 of [RFC2068]
        if timeout is not None:
            try:
                timeout = int(timeout)
            except ValueError: # no number
                if timeout.lower() == "infinite":
                    value = "Infinite"
                else:
                    raise ValueError("either number of seconds or 'infinite'")
            else:
                if timeout > MAX_TIMEOUT:
                    raise ValueError("timeout too big")
                value = "Second-%d" % timeout
            headers["Timeout"] = value
        # RFC 2518, 8.10.4 Depth and Locking
        # Values other than
        # 0 or infinity MUST NOT be used with the Depth header on a LOCK
        # method.
        if depth is not None:
            headers["Depth"] = util.get_depth(depth, ("0", "infinity"))
        content = creator.create_lock(scope, type_, owner)
        # set a specialized ResponseType as instance var
        self.ResponseType = partial(WebDAVLockResponse, self, uri)
        try:
            lock_response = self._request("LOCK", uri, content, headers)
            if lock_response == OK:
                self.locks[lock_response._tag] = lock_response
            return lock_response
        finally:
            # remove the formerly set ResponseType from the instance
            del self.ResponseType

    def unlock(self, uri_or_lock, locktoken=None, headers=None):
        """Make UNLOCK request and return WebDAVResponse.

        uri_or_lock -- Resource URI to unlock or WebDAVLockResponse.
        locktoken -- Use this lock token for unlocking. If not given, the
                     registered locks (self.locks) will be referenced.
        headers -- If given, must be a mapping with headers to set.

        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        if isinstance(uri_or_lock, WebDAVLockResponse):
            uri = uri_or_lock._uri
            tag = uri_or_lock._tag
            locktoken = uri_or_lock.locktokens[0]
            # uri is already prepared in WebDAVLockResponse
            (_, headers) = self._prepare("", headers)
        else:
            tag = util.make_absolute(self, uri_or_lock)
            if locktoken is None:
                try:
                    lock = self.locks[tag]
                except KeyError:
                    raise ValueError("no lock token")
                tag = lock._tag
                locktoken = lock.locktokens[0]
            (uri, headers) = self._prepare(uri_or_lock, headers)
        # RFC 2518, 9.5 Lock-Token Header
        # Lock-Token = "Lock-Token" ":" Coded-URL
        headers["Lock-Token"] = "<%s>" % locktoken
        response = self._request("UNLOCK", uri, None, headers)
        # RFC 2518, 8.11 UNLOCK Method
        # The 204 (No Content) status code is used instead of 200 (OK) because
        # there is no response entity body.
        if response == NO_CONTENT:
            try:
                del self.locks[tag]
            except KeyError:
                pass
        return response


class ExtendedWebDAVClient(CoreWebDAVClient):
    """WebDAV client with versioning extensions (RFC 3253)."""
    def __report(self, uri, depth, content, headers):
        depth = util.get_depth(depth)
        (uri, headers) = self._prepare(uri, headers)
        # RFC 3253, 3.6 REPORT Method
        # The request MAY include a Depth header.  If no Depth header is
        # included, Depth:0 is assumed.
        headers["Depth"] = depth
        headers["Content-Type"] = "application/xml"
        return self._request("REPORT", uri, content, headers)

    def version_tree_report(self, uri, depth=0, properties=None,
                            elements=None, namespaces=None, headers=None):
        """Make a version-tree-REPORT request and return status.

        uri -- Resource or collection to get report for.
        depth -- Either 0 or 1 or "infinity". Default is zero.
        properties -- If given, an iterable with all requested properties is
                      expected.
        elements -- An iterable with additional XML (ElementTree) elements to
                    append to the version-tree.
        namespaces -- Mapping with namespaces for given properties, if needed.
        headers -- If given, must be a mapping with headers to set.

        Raise ValueError, if an illegal depth value was given.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        args = (properties, elements, namespaces)
        content = creator.create_report_version_tree(*args)
        return self.__report(uri, depth, content, headers)

    # compatibility
    report = version_tree_report

    def expand_property_report(self, uri, depth=0, properties=None,
                               elements=None, namespaces=None, headers=None):
        """Make a expand-property-REPORT request and return status.

        uri -- Resource or collection to get report for.
        depth -- Either 0 or 1 or "infinity". Default is zero.
        properties -- If given, an iterable with all requested properties is
                      expected.
        elements -- An iterable with additional XML (ElementTree) elements to
                    append to the version-tree.
        namespaces -- Mapping with namespaces for given properties, if needed.
        headers -- If given, must be a mapping with headers to set.

        Raise ValueError, if an illegal depth value was given.
        Raise HTTPUserError on 4xx HTTP status codes.
        Raise HTTPServerError on 5xx HTTP status codes.

        """
        args = (properties, elements, namespaces)
        content = creator.create_report_expand_property(*args)
        return self.__report(uri, depth, content, headers)


class WebDAVClient(ExtendedWebDAVClient):
    """Mini WebDAV client.

    This object has the following attributes:

    host -- Given host on initialization.
    port -- Given port on initialization.
    protocol -- Used protocol. Either chosen by the port number or taken
                from given value in initialization.
    headers -- Dictionary with headers to send with every request.
    cookie -- If set with setcookie: the given object.

    """
