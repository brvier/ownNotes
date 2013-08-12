#!/usr/bin/python
# -*- coding: utf-8 

import ownnotes

content = ownnotes.loadNote('/home/nemo/.ownnotes/Untitled 4.txt')
content = ownnotes.reHighlight(content)
print type(content)
print content