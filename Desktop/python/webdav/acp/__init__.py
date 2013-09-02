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


from webdav import Constants 
from webdav.acp.Acl import ACL
from webdav.acp.Ace import ACE
from webdav.acp.GrantDeny import GrantDeny
from webdav.acp.Privilege import Privilege
from webdav.acp.Principal import Principal


__version__ = "$LastChangedRevision$"


privileges = [Constants.TAG_READ, Constants.TAG_WRITE, Constants.TAG_WRITE_PROPERTIES, 
              Constants.TAG_WRITE_CONTENT, Constants.TAG_UNLOCK, Constants.TAG_READ_ACL, 
              Constants.TAG_READ_CURRENT_USER_PRIVILEGE_SET, Constants.TAG_WRITE_ACL, Constants.TAG_ALL, 
              Constants.TAG_BIND, Constants.TAG_UNBIND, Constants.TAG_TAMINO_SECURITY,
              Constants.TAG_BIND_COLLECTION, Constants.TAG_UNBIND_COLLECTION, Constants.TAG_READ_PRIVATE_PROPERTIES,
              Constants.TAG_WRITE_PRIVATE_PROPERTIES]
Privilege.registerPrivileges(privileges)
