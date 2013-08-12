# pylint: disable-msg=R0903,W0142,W0221,W0212,W0104,W0511,C0103,R0901
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
Handles WebDAV responses.
"""


from davlib import _parse_status
import qp_xml
from webdav import Constants, logger
import sys
import time
import rfc822
import urllib
# Handling Jython 2.5 bug concerning the date pattern
# conversion in time.strptime
try:
    from java.lang import IllegalArgumentException
except ImportError:
    class IllegalArgumentException(object):
        pass


__version__ = "$LastChangedRevision$"


class HttpStatus(object):
    """
    TBD
    
    @ivar code:
    @type code:
    @ivar reason:
    @type reason:
    @ivar errorCount:
    @type errorCount: int
    """
    
    def __init__(self, elem):
        """
        TBD
        
        @param elem: ...
        @type elem: instance of L{Element}
        """
        self.code, self.reason = _parse_status(elem)
        self.errorCount = (self.code >= Constants.CODE_LOWEST_ERROR)
    def __str__(self):
        return "HTTP status %d: %s" % (self.code, self.reason)

        
class MultiStatusResponse(dict):
    """
    TBD
    
    @ivar status:
    @type status:
    @ivar reason:
    @type reason:
    @ivar errorCount:
    @type errorCount:
    """
    
    # restrict instance variables
    __slots__ = ('errorCount', 'reason', 'status')

    def __init__(self, domroot):
        dict.__init__(self)
        self.errorCount = 0
        self.reason = None
        self.status = Constants.CODE_MULTISTATUS
        if (domroot.ns != Constants.NS_DAV) or (domroot.name != Constants.TAG_MULTISTATUS):
            raise ResponseFormatError(domroot, 'Invalid response: <DAV:multistatus> expected.')
        self._scan(domroot)
    
    def getCode(self):
        if self.errorCount == 0:
            return Constants.CODE_SUCCEEDED
        if  len(self) > self.errorCount:
            return Constants.CODE_MULTISTATUS
        return self.values()[0].code

    def getReason(self):
        result = ""
        for response in self.values():
            if response.code > Constants.CODE_LOWEST_ERROR:
                result += response.reason
        return result                    
    
    def __str__(self):
        result = u""
        for key, value in self.items():
            if isinstance(value, PropertyResponse):
                result += "Resource at %s has %d properties (%s) and %d errors\n" % (
                    key, len(value), ", ".join([prop[1] for prop in value.keys()]), value.errorCount)
            else:
                result += "Resource at %s returned " % key + unicode(value)
        return result.encode(sys.stdout.encoding or "ascii", "replace")
    
    def _scan(self, root):
        for child in root.children:
            if child.ns != Constants.NS_DAV:
                continue
            if child.name == Constants.TAG_RESPONSEDESCRIPTION:
                self.reason = child.textof()
            elif child.name == Constants.TAG_RESPONSE:
                self._scanResponse(child)
            ### unknown child element
        
    def _scanResponse(self, elem):
        hrefs = []
        response = None
        for child in elem.children:
            if child.ns != Constants.NS_DAV:
                continue
            if child.name == Constants.TAG_HREF:
                try:
                    href = _unquoteHref(child.textof())
                except UnicodeDecodeError:
                    raise ResponseFormatError(child, "Invalid 'href' data encoding.")
                hrefs.append(href)
            elif child.name == Constants.TAG_STATUS:
                self._scanStatus(child, *hrefs)
            elif child.name == Constants.TAG_PROPERTY_STATUS:
                if not response:
                    if len(hrefs) != 1:
                        raise ResponseFormatError(child, 'Invalid response: One <DAV:href> expected.')
                    response = PropertyResponse()                    
                    self[hrefs[0]] = response                    
                response._scan(child)
            elif child.name == Constants.TAG_RESPONSEDESCRIPTION:
                for href in hrefs:
                    self[href].reasons.append(child.textOf())            
            ### unknown child element
        if response and response.errorCount > 0:
            self.errorCount += 1
                                    
    def _scanStatus(self, elem, *hrefs):
        if  len(hrefs) == 0:
            raise ResponseFormatError(elem, 'Invalid response: <DAV:href> expected.')
        status = HttpStatus(elem)
        for href in hrefs:
            self[href] = status
            if  status.errorCount:
                self.errorCount += 1

    # Instance properties
    code = property(getCode, None, None, "HTTP response code")



class PropertyResponse(dict):
    """
    TBD
    
    @ivar errors:
    @type errors: list of ...
    @ivar reasons:
    @type reasons: list of ...
    @ivar failedProperties:
    @type failedProperties: dict of ...
    """

    # restrict instance variables
    __slots__ = ('errors', 'reasons', 'failedProperties')

    def __init__(self):
        dict.__init__(self)
        self.errors = []
        self.reasons = []
        self.failedProperties = {}

    def __str__(self):
        result = ""
        for value in self.values():
            result += value.name + '= ' + value.textof() + '\n'
        result += self.getReason()
        return result
        
    def getCode(self):
        if  len(self.errors) == 0:
            return Constants.CODE_SUCCEEDED
        if  len(self) > 0:
            return Constants.CODE_MULTISTATUS
        return self.errors[-1].code       

    def getReason(self):
        result = ""
        if len(self.errors) > 0:
            result = "Failed for: "   + repr(self.failedProperties.keys()) + "\n"
        for error in self.errors:
            result += "%s (%d).  " % (error.reason, error.code)
        for reason in self.reasons:
            result += "%s.  " % reason
        return result
        
    def _scan(self, element):
        status = None
        statusElement = element.find(Constants.TAG_STATUS, Constants.NS_DAV)
        if statusElement:
            status = HttpStatus(statusElement)
            if status.errorCount:
                self.errors.append(status)
        
        propElement = element.find(Constants.TAG_PROP, Constants.NS_DAV)
        if propElement:
            for prop in propElement.children:
                if status.errorCount:
                    self.failedProperties[(prop.ns, prop.name)]= status
                else:
                    prop.__class__ = Element     # bad, bad trick
                    self[prop.fullname] = prop
        reasonElement = element.find(Constants.TAG_RESPONSEDESCRIPTION, Constants.NS_DAV)
        if reasonElement:
            self.reasons.append(reasonElement.textOf())
        
    # Instance properties
    code = property(getCode, None, None, "HTTP response code")
    errorCount = property(lambda self: len(self.errors), None, None, "HTTP response code")
    reason = property(getReason, None, None, "HTTP response code")



        
class LiveProperties(object):
    """
    This class provides convenient access to the WebDAV 'live' properties of a resource.
    WebDav 'live' properties are defined in RFC 4918, Section 15. 
    Each property is converted from string to its natural data type.
    
    @version: $Revision$
    @author: Roland Betz
    """
    
    # restrict instance variables
    __slots__ = ('properties')

    NAMES = (Constants.PROP_CREATION_DATE, Constants.PROP_DISPLAY_NAME,
             Constants.PROP_CONTENT_LENGTH, Constants.PROP_CONTENT_TYPE, Constants.PROP_ETAG,
             Constants.PROP_LAST_MODIFIED, Constants.PROP_OWNER,
             Constants.PROP_LOCK_DISCOVERY, Constants.PROP_RESOURCE_TYPE, Constants.PROP_SUPPORTED_LOCK )
    _logger = logger.getDefaultLogger()
    
    def __init__(self, properties=None, propElement=None):
        """
        Construct C{LiveProperties} from a dictionary of properties containing
        live properties or from a XML 'prop' element.
        
        @param properties: map as implemented by class L{PropertyResponse}
        @param propElement: C{Element} value
        """
        
        assert isinstance(properties, PropertyResponse) or \
               isinstance(propElement, qp_xml._element), \
                "Argument properties has type %s" % str(type(properties))
        self.properties = dict()
        for name, value in properties.items():
            if name[0] == Constants.NS_DAV and name[1] in self.NAMES:
                self.properties[name[1]] = value

    def getContentLanguage(self):
        """
        Return the language of a resource's textual content or C{None}.
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_CONTENT_LANGUAGE)
        if xml:
            return xml.textof()

    def getContentLength(self):
        """
        Returns the length of the resource's content in bytes or C{None}.
        
        @rtype: C{int}
        """
        
        xml = self.properties.get(Constants.PROP_CONTENT_LENGTH)
        if xml:
            try:
                return int(xml.textof())
            except (ValueError, TypeError):
                self._logger.debug("Cannot convert content length to a numeric value.", exc_info=True)

    def getContentType(self):
        """
        Return the resource's content MIME type or C{None}.
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_CONTENT_TYPE)
        if xml:
            return xml.textof()

    def getCreationDate(self):
        """
        Return the creation date as time tuple or C{None}.
                
        @rtype: C{time.struct_time}
        """
        
        datetimeString = None
        xml = self.properties.get(Constants.PROP_CREATION_DATE)
        if xml:
            datetimeString = xml.textof()
        
        if datetimeString:
            try:
                return _parseIso8601String(datetimeString)
            except ValueError:
                self._logger.debug(
                    "Invalid date format: The server must provide an ISO8601 formatted date string.", exc_info=True)
            
    def getEntityTag(self):
        """
        Return a entity tag which is unique for a particular version of a resource or C{None}.
        Different resources or one resource before and after modification have different etags. 
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_ETAG)
        if xml:
            return xml.textof()
            
    def getDisplayName(self):
        """
        Returns a resource's display name or C{None}.
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_DISPLAY_NAME)
        if xml:
            return xml.textof()

    def getLastModified(self):
        """
        Return last modification of a resource as time tuple or C{None}.
        
        @rtype: C{time.struct_time}
        """
        
        datetimeString = None
        xml = self.properties.get(Constants.PROP_LAST_MODIFIED)
        if xml:
            datetimeString = xml.textof()

        if datetimeString:
            try:
                result = rfc822.parsedate(datetimeString)
                if result is None:
                    result = _parseIso8601String(datetimeString) # Some servers like Tamino use ISO 8601
                return time.struct_time(result)
            except ValueError:
                self._logger.debug(
                    "Invalid date format: "
                    "The server must provide a RFC822 or ISO8601 formatted date string.", exc_info=True)
                
    def getLockDiscovery(self):
        """
        Return all current locks applied to a resource or C{None} if it is not locked. The lock is represented by 
        a C{lockdiscovery} DOM element according to RFC 4918, Section 15.8.1.
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_LOCK_DISCOVERY)
        if xml:
            return _scanLockDiscovery(xml)

    def getResourceType(self):
        """
        Return a resource's WebDAV type:
         * 'collection' => WebDAV Collection
         * 'resource' => WebDAV resource
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_RESOURCE_TYPE)
        if xml and xml.children:
            return xml.children[0].name
        return "resource"

    def getSupportedLock(self):
        """
        Return a DOM element describing all supported lock options for a resource.
        Shared and exclusive write locks are usually supported. The supported locks are represented by       
        a C{supportedlock} DOM element according to RFC 4918, Section 15.10.1.
        
        rtype: C{string}
        """
        
        return self.properties.get(Constants.PROP_SUPPORTED_LOCK)

    def getOwnerAsUrl(self):
        """
        Return a resource's owner represented as URL or C{None}.
        
        @rtype: C{string}
        """
        
        xml = self.properties.get(Constants.PROP_OWNER)
        if xml and xml.children:
            return xml.children[0].textof()

    def __str__(self):
        result = ""
        result += " Name=%s" % self.getDisplayName()
        result += "\n Type=%s" % self.getResourceType()
        result += "\n Length=%s" % self.getContentLength()
        result += "\n Content Type=%s" % self.getContentType()
        result += "\n ETag=%s" % self.getEntityTag()
        result += "\n Created="
        if self.getCreationDate():
            result += time.strftime("%c GMT", self.getCreationDate())
        else:
            result += "None"
        result += "\n Modified="
        if self.getLastModified():
            result += time.strftime("%c GMT", self.getLastModified())
        else:
            result += "None"
        return result


def _parseIso8601String(date):
    """ 
    Parses the given ISO 8601 string and returns a time tuple.
    The strings should be formatted according to RFC 3339 (see section 5.6).
    But currently there are two exceptions:
        1. Time offset is limited to "Z".
        2. Fragments of seconds are ignored.
    """
    if "." in date and "Z" in date: # Contains fragments of second?
        secondFragmentPos = date.rfind(".")
        timeOffsetPos = date.rfind("Z")
        date = date[:secondFragmentPos] + date[timeOffsetPos:]
    try:
        timeTuple = time.strptime(date, Constants.DATE_FORMAT_ISO8601)
    except IllegalArgumentException: # Handling Jython 2.5 bug concerning the date pattern accordingly
        import _strptime # Using the Jython fall back solution directly
        timeTuple = _strptime.strptime(date, Constants.DATE_FORMAT_ISO8601)
    return timeTuple


class ResponseFormatError(IOError):
    """
    An instance of this class is raised when the web server returned a webdav
    reply which does not adhere to the standard and cannot be recognized.
    """
    def __init__(self, element, message= None):
        IOError.__init__(self, "ResponseFormatError at element %s: %s"  % (element.name, message))
        self.element = element
        self.message = message
        
    
class Element(qp_xml._element):
    """
    This class improves the DOM interface (i.e. element interface) provided by the qp_xml module
    TODO: substitute qp_xml by 'real' implementation. e.g. domlette
    """
    def __init__(self, namespace, name, cdata=''):
        qp_xml._element.__init__(self, ns=namespace, name=name, lang=None, parent=None,
                    children=[], ns_scope={}, attrs={},
                    first_cdata=cdata, following_cdata='')
                    
    def __str__(self):
        return self.textof()
        
    def __getattr__(self, name):
        if  (name == 'fullname'):
            return (self.__dict__['ns'], self.__dict__['name'])
        raise AttributeError, name

    def add(self, child):
        self.children.append(child)
        return child

def _scanLockDiscovery(root):
    assert root.name == Constants.PROP_LOCK_DISCOVERY, "Invalid lock discovery XML element"
    active = root.find(Constants.TAG_ACTIVE_LOCK, Constants.NS_DAV)
    if active:
        return _scanActivelock(active)
    return None
    
def _scanActivelock(root):
    assert root.name == Constants.TAG_ACTIVE_LOCK, "Invalid active lock XML element"
    token = _scanOrError(root, Constants.TAG_LOCK_TOKEN)
    value = _scanOrError(token, Constants.TAG_HREF)
    owner = _scanOwner(root)
    depth = _scanOrError(root, Constants.TAG_LOCK_DEPTH)
    return (value.textof(), owner, depth.textof())

def _scanOwner(root):
    owner = root.find(Constants.TAG_LOCK_OWNER, Constants.NS_DAV)
    if owner:
        href = owner.find(Constants.TAG_HREF, Constants.NS_DAV)
        if href:
            return href.textof()
        return owner.textof()
    return None
    
def _scanOrError(elem, childName):
    child = elem.find(childName, Constants.NS_DAV)
    if not child:
        raise ResponseFormatError(elem, "Invalid response: <"+childName+"> expected")
    return child
    
         
def _unquoteHref(href):
    #print "*** Response HREF=", repr(href)
    if type(href) == type(u""):
        try: 
            href = href.encode('ascii')
        except UnicodeError:    # URL contains unescaped non-ascii character
            # handle bug in Tamino webdav server
            return urllib.unquote(href)
    href = urllib.unquote(href)
    if Constants.CONFIG_UNICODE_URL:
        return unicode(href, 'utf-8')
    else:
        return unicode(href, 'latin-1')
