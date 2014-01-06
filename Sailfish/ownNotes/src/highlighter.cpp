/****************************************************************************
**
** Copyright (C) 2011 Nokia Corporation and/or its subsidiary(-ies).
** All rights reserved.
** Contact: Nokia Corporation (qt-info@nokia.com)
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of Nokia Corporation and its Subsidiary(-ies) nor
**     the names of its contributors may be used to endorse or promote
**     products derived from this software without specific prior written
**     permission.
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
** $QT_END_LICENSE$
**
****************************************************************************/

#include <QtGui>

#include "highlighter.h"

Highlighter::Highlighter(QTextDocument *parent)
    : QSyntaxHighlighter(parent)
{

}

void Highlighter::updateRules()
{
    HighlightingRule rule;

    highlightingRules.clear();

    italicFormat.setFontItalic(true);
    rule.pattern = QRegExp("\\*([^\\\\]+)\\*");
    rule.format = italicFormat;
    highlightingRules.append(rule);

    boldFormat.setFontWeight(QFont::Bold);
    rule.pattern = QRegExp("\\*\\*([^\\\\]+)\\*\\*");
    rule.format = boldFormat;
    highlightingRules.append(rule);

    header6Format.setForeground(QColor(m_highlightColor));
    header6Format.setFontPointSize(m_baseFontPointSize*0.8);
    rule.pattern = QRegExp("^######\\s(.+)");
    rule.format = header6Format;
    highlightingRules.append(rule);

    header5Format.setForeground(QColor(m_highlightColor));
    header5Format.setFontPointSize(m_baseFontPointSize*0.9);
    rule.pattern = QRegExp("^#####\\s(.+)");
    rule.format = header5Format;
    highlightingRules.append(rule);

    header4Format.setForeground(QColor(m_highlightColor));
    header4Format.setFontPointSize(m_baseFontPointSize*1.0);
    rule.pattern = QRegExp("^####\\s(.+)");
    rule.format = header4Format;
    highlightingRules.append(rule);

    header3Format.setForeground(QColor(m_highlightColor));
    header3Format.setFontPointSize(m_baseFontPointSize*1.1);
    rule.pattern = QRegExp("^###\\s(.+)");
    rule.format = header3Format;
    highlightingRules.append(rule);

    header2Format.setForeground(QColor(m_highlightColor));
    header2Format.setFontPointSize(m_baseFontPointSize*1.2);
    rule.pattern = QRegExp("^##\\s(.+)");
    rule.format = header2Format;
    highlightingRules.append(rule);

    header1Format.setForeground(QColor(m_secondaryHighlightColor));
    header1Format.setFontPointSize(m_baseFontPointSize*1.4);
    rule.pattern = QRegExp("^#\\s(.+)");
    rule.format = header1Format;
    highlightingRules.append(rule);

    imageFormat.setForeground(QColor(m_secondaryColor));
    rule.pattern = QRegExp("!\\[(.*)\\]\\((.*)\\)");
    rule.format = imageFormat;
    highlightingRules.append(rule);

    linkFormat.setForeground(QColor(m_secondaryHighlightColor));
    rule.pattern = QRegExp("\\[(.*)\\]\\((.*)\\)");
    rule.format = linkFormat;
    highlightingRules.append(rule);

    rule.pattern = QRegExp("^--*$");
    rule.format = header2Format;
    highlightingRules.append(rule);

    rule.pattern = QRegExp("^==*$");
    rule.format = header1Format;
    highlightingRules.append(rule);

}

void Highlighter::highlightBlock(const QString &text)
{
    if (m_baseFontPointSize == 0.0)
            return;

    if (this->currentBlock().blockNumber() == 0)
        setFormat(0, this->currentBlock().length(), header1Format);
    else {
        QRegExp title("^==*$");
        QRegExp subtitle("^--*$");

        qDebug() << this->currentBlock().next().text();

        if (title.indexIn(this->currentBlock().next().text()) >= 0) {
            setFormat(0, this->currentBlock().length(), header1Format);
        }
        if (subtitle.indexIn(this->currentBlock().next().text()) >= 0) {
            setFormat(0, this->currentBlock().length(), header1Format);
        }

    }

    foreach (const HighlightingRule &rule, highlightingRules) {
        QRegExp expression(rule.pattern);
        int index = expression.indexIn(text);
        while (index >= 0) {
            int length = expression.matchedLength();
            setFormat(index, length, rule.format);
            index = expression.indexIn(text, index + length);
        }
    }
}

void Highlighter::setStyle(QString primaryColor,
                           QString secondaryColor,
                           QString highlightColor,
                           QString secondaryHighlightColor,
                           qreal baseFontPointSize)
{
    m_primaryColor = QString(primaryColor);
    m_secondaryColor = QString(secondaryColor);
    m_highlightColor = QString(highlightColor);
    m_secondaryHighlightColor = QString(secondaryHighlightColor);
    m_baseFontPointSize = baseFontPointSize;
    this->updateRules();
    this->rehighlight();
}
