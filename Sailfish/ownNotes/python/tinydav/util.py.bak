# Utility function for tinydav WebDAV client.
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
"""Utility functions and classes for tinydav WebDAV client."""
import sys
PYTHON2 = ((2, 5) <= sys.version_info <= (3, 0))

from email.encoders import encode_base64
from email.mime.application import MIMEApplication
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from os import path
import re

if PYTHON2:
    from urlparse import urlunsplit
else:
    from urllib.parse import urlunsplit

from tinydav.exception import HTTPError

__all__ = (
    "FakeHTTPRequest", "make_absolute", "make_multipart",
    "extract_namespace", "get_depth"
)

authparser = re.compile("""
    (?P<schema>Basic|Digest)
    (
        \s+
        (?:realm="(?P<realm>[^"]*)")?
        (?:domain="(?P<domain>[^"]*)")?
        (?:nonce="(?P<nonce>[^"]*)")?
        (?:opaque="(?P<opaque>[^"]*)")?
        (?:stale=(?P<stale>(true|false|TRUE|FALSE)))?
        (?:algorithm="(?P<algorithm>\w+)")?
    )+
""", re.VERBOSE)

DEFAULT_CONTENT_TYPE = "application/octet-stream"


class FakeHTTPRequest(object):
    """Fake HTTP request object needed for cookies.
    
    See http://docs.python.org/library/cookielib.html#cookiejar-and-filecookiejar-objects

    """
    def __init__(self, client, uri, headers):
        """Initialize the fake HTTP request object.

        client -- HTTPClient object or one of its subclasses.
        uri -- The URI to call.
        headers -- Headers dict to add cookie stuff to.

        """
        self._client = client
        self._uri = uri
        self._headers = headers

    def get_full_url(self):
        return make_absolute(self._client, self._uri)

    def get_host(self):
        return self._client.host

    def is_unverifiable(self):
        return False

    def get_origin_req_host(self):
        return self.get_host()

    def get_type(self):
        return self._client.protocol

    def has_header(self, name):
        return (name in self._headers)

    def add_unredirected_header(self, key, header):
        self._headers[key] = header


def make_absolute(httpclient, uri):
    """Return correct absolute URI.

    httpclient -- HTTPClient instance with protocol, host and port attribute.
    uri -- The destination path.

    """
    netloc = "%s:%d" % (httpclient.host, httpclient.port)
    parts = (httpclient.protocol, netloc, uri, None, None)
    return urlunsplit(parts)


class Multipart(object):
    def __init__(self, data, default_encoding="ascii", with_filenames=False):
        self.data = data
        self.default_encoding = default_encoding
        self.with_filenames = with_filenames
        self._mp = MIMEMultipart("form-data")
        self._files = list()

    def _create_non_file_parts(self):
        items_iterator = self.data.iteritems() if PYTHON2 else self.data.items()
        for (key, data) in items_iterator:
            # Are there explicit encodings/content-types given?
            # Note: Cannot do a (value, encoding) = value here as fileobjects 
            # then would get iterated, which is not what we want.
            if isinstance(data, tuple) and (len(data) == 2):
                (value, encoding) = data
            else:
                (value, encoding) = (data, None)
            # collect file-like objects
            if hasattr(value, "read"):
                self._files.append((key, value, encoding))
            # no file-like object
            else:
                if isinstance(value, MIMEBase):
                    part = value
                else:
                    encoding = encoding if encoding else default_encoding
                    part = MIMEText(value, "plain", encoding)
                add_disposition(part, key)
                self._mp.attach(part)

    def _add_disposition(self, part, name, filename=None,
                         disposition="form-data"):
        """Add a Content-Disposition header to the part.

        part -- Part to add header to.
        name -- Name of the part.
        filename -- Add this filename as parameter, if given.
        disposition -- Value of the content-disposition header.

        """
        # RFC 2388 Returning Values from Forms: multipart/form-data
        # Each part is expected to contain a content-disposition header
        # [RFC 2183] where the disposition type is "form-data", and where the
        # disposition contains an (additional) parameter of "name", where the
        # value of that parameter is the original field name in the form.
        params = dict(name=name)
        if self.with_filenames and (filename is not None):
            # RFC 2388 Returning Values from Forms: multipart/form-data
            # The original local file name may be supplied as well, either as
            # a "filename" parameter either of the "content-disposition: 
            # form-data" header or, in the case of multiple files, in a
            # "content-disposition: file" header of the subpart.
            params["filename"] = path.basename(filename)
        part.add_header("Content-Disposition", disposition, **params)


def make_multipart(content, default_encoding="ascii", with_filenames=False):
    """Return the headers and content for multipart/form-data.

    content -- Dict with content to POST. The dict values are expected to
               be unicode or decodable with us-ascii.
    default_encoding -- Send multipart with this encoding, if no special 
                        encoding was given with the content. Default is ascii.
    with_filenames -- If True, a multipart's files will be sent with the
                      filename paramenter set. Default is False.

    """
    def add_disposition(part, name, filename=None, disposition="form-data"):
        """Add a Content-Disposition header to the part.

        part -- Part to add header to.
        name -- Name of the part.
        filename -- Add this filename as parameter, if given.
        disposition -- Value of the content-disposition header.

        """
        # RFC 2388 Returning Values from Forms: multipart/form-data
        # Each part is expected to contain a content-disposition header
        # [RFC 2183] where the disposition type is "form-data", and where the
        # disposition contains an (additional) parameter of "name", where the
        # value of that parameter is the original field name in the form.
        params = dict(name=name)
        if with_filenames and (filename is not None):
            # RFC 2388 Returning Values from Forms: multipart/form-data
            # The original local file name may be supplied as well, either as
            # a "filename" parameter either of the "content-disposition: 
            # form-data" header or, in the case of multiple files, in a
            # "content-disposition: file" header of the subpart.
            params["filename"] = path.basename(filename)
        part.add_header("Content-Disposition", disposition, **params)

    def create_part(key, fileobject, content_type, multiple=False):
        """Create and return a multipart part as to given file data.

        key -- Field name.
        fileobject -- The file-like object to add to the part.
        content_type -- Content-type of the file. If None, use default.
        multiple -- If true, use Content-Disposition: file.

        """
        if not content_type:
            content_type = DEFAULT_CONTENT_TYPE
        (maintype, subtype) = content_type.split("/")
        part = MIMEBase(maintype, subtype)
        part.set_payload(fileobject.read())
        encode_base64(part)
        filename = getattr(fileobject, "name", None)
        kwargs = dict()
        if multiple:
            # RFC 2388 Returning Values from Forms: multipart/form-data
            # The original local file name may be supplied as well, either as
            # a "filename" parameter either of the "content-disposition: 
            # form-data" header or, in the case of multiple files, in a
            # "content-disposition: file" header of the subpart.
            kwargs["disposition"] = "file"
        add_disposition(part, key, filename, **kwargs)
        return part

    # RFC 2388 Returning Values from Forms: multipart/form-data
    mime = MIMEMultipart("form-data")
    files = list()
    items_iterator = content.iteritems() if PYTHON2 else content.items()
    for (key, data) in items_iterator:
        # Are there explicit encodings/content-types given?
        # Note: Cannot do a (value, encoding) = value here as fileobjects then
        # would get iterated, which is not what we want.
        if isinstance(data, tuple) and (len(data) == 2):
            (value, encoding) = data
        else:
            (value, encoding) = (data, None)
        # collect file-like objects
        if hasattr(value, "read"):
            files.append((key, value, encoding))
        # no file-like object
        else:
            if isinstance(value, MIMEBase):
                part = value
            else:
                encoding = encoding if encoding else default_encoding
                part = MIMEText(value, "plain", encoding)
            add_disposition(part, key)
            mime.attach(part)

    filecount = len(files)
    if filecount == 1:
        filedata = files[0]
        part = create_part(*filedata)
        mime.attach(part)
    elif filecount > 1: 
        # RFC 2388 Returning Values from Forms: multipart/form-data
        # 4.2 Sets of files
        # If the value of a form field is a set of files rather than a single
        # file, that value can be transferred together using the
        # "multipart/mixed" format.
        mixed = MIMEMultipart("mixed")
        for filedata in files:
            part = create_part(multiple=True, *filedata)
            mixed.attach(part)
        mime.attach(mixed)

    # mime.items must be called after mime.as_string when the headers shall
    # contain the boundary
    complete_mime = mime.as_string()
    headers = dict(mime.items())
    # trim headers from create mime as these will later be added by httplib.
    payload_start = complete_mime.index("\n\n") + 2
    payload = complete_mime[payload_start:]
    return (headers, payload)


def extract_namespace(key):
    """Return the namespace in key or None, when no namespace is in key.

    key -- String to get namespace from

    """
    if not key.startswith("{"):
        return None
    return key[1:].split("}")[0]


def get_depth(depth, allowed=("0", "1", "infinity")):
    """Return string with depth.

    depth -- Depth value to check.
    allowed -- Iterable with allowed depth header values.

    Raise ValueError, if an illegal depth was given.

    """
    depth = str(depth).lower()
    if depth not in allowed:
        raise ValueError("illegal depth %s" % depth)
    return depth


def get_cookie_response(tiny_response):
    """Return response object suitable with cookielib.

    This makes the httplib.HTTPResponse compatible with cookielib.

    """
    if isinstance(tiny_response, HTTPError):
        tiny_response = tiny_response.response
    tiny_response.response.info = lambda: tiny_response.response.msg
    return tiny_response.response


def parse_authenticate(value):
    """Parse www-authenticate header and return dict with values.

    Return empty dict when value doesn't match a www-authenticate header value.

    value -- String value of www-authenticate header.

    """
    sre = authparser.match(value)
    if sre:
        return sre.groupdict()
    return dict()
