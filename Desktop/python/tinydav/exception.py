# Exceptions for the tinydav WebDAV client.
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
"""Exceptions for the tinydav WebDAV client."""


class HTTPError(Exception):
    """Base exception class for HTTP errors.

    response -- httplib.Response object.
    method -- String with uppercase method name.

    This object has the following attributes:
      response -- The HTTPResponse object.
    
    """
    def __init__(self, response):
        """Initialize the HTTPError.

        response -- HTTPClient or one of its subclasses.
        method -- The uppercase method name where the error occured.

        This instance has the following attributes:

        response -- Given HTTPClient.

        """
        Exception.__init__(self)
        self.response = response

    def __repr__(self):
        """Return representation of an HTTPError."""
        return "<%s: %d>" % (self.__class__.__name__, self.response)

    def __str__(self):
        """Return string representation of an HTTPError."""
        return self.response.statusline


class HTTPUserError(HTTPError):
    """Exception class for 4xx HTTP errors."""


class HTTPServerError(HTTPError):
    """Exception class for 5xx HTTP errors."""

