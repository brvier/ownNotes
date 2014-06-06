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

# Module from the libwebdav module

""""
Module provides access to a configured logger instance.
The logger writes C{sys.stdout}.
"""

import logging
from logging.handlers import RotatingFileHandler
import os


class Logger():

    def __init__(self, debug=False):
        self.logger = logging.getLogger('ownNotes')
        formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')

        if debug:
            # File Log
            file_hdlr = RotatingFileHandler(os.path.join(
                                            os.path.expanduser('~/.ownnotes/'),
                                            'OwnNotes Log.log'),
                                            100000, 1)
            file_hdlr.setFormatter(formatter)
            file_hdlr.setLevel(logging.DEBUG)
            self.logger.addHandler(file_hdlr)

        # Steam Log
        steam_hdlr = logging.StreamHandler()
        steam_hdlr.setFormatter(formatter)
        steam_hdlr.setLevel(logging.DEBUG)
        self.logger.addHandler(steam_hdlr)

        if debug:
            self.logger.setLevel(logging.DEBUG)
