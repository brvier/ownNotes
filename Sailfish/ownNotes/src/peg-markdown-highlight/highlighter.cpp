#include <QtGui>
#include "highlighter.h"
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QWidget>
#include <QtGui/QPalette>

extern "C" {
#include "pmh_styleparser.h"
}


// Convert unicode code point offsets (this is what we get from the parser) to
// QString character offsets (QString uses UTF-16 units as characters, so
// sometimes two characters (a "surrogate pair") are needed to represent one
// code point):
static void convertOffsets(pmh_element **elements, QString str)
{
    // Walk through the whole string only once, and gather all surrogate pair indexes
    // (technically, the indexes of the high characters (which come before the low
    // characters) in each pair):
    QList<int> surrogatePairIndexes;
    int strLen = str.length();
    int i = 0;
    while (i < strLen)
    {
        if (str.at(i).isHighSurrogate())
            surrogatePairIndexes.append(i);
        i++;
    }

    // If the text does not contain any surrogate pairs, we're done (the indexes
    // are already correct):
    if (surrogatePairIndexes.length() == 0)
        return;

    // Use our list of surrogate pair indexes to shift the indexes of all
    // language elements:
    for (int langType = 0; langType < pmh_NUM_LANG_TYPES; langType++)
    {
        pmh_element *cursor = elements[langType];
        while (cursor != NULL)
        {
            unsigned posShift = 0;
            unsigned endShift = 0;
            unsigned passedPairs = 0;
            for (int j = 0; j < surrogatePairIndexes.length(); j++)
            {
                unsigned u = surrogatePairIndexes.at(j) - passedPairs;
                if (u < cursor->pos)
                {
                    posShift++;
                    endShift++;
                }
                else if (u < cursor->end)
                {
                    endShift++;
                }
                else
                    break;
                passedPairs++;
            }
            cursor->pos += posShift;
            cursor->end += endShift;
            cursor = cursor->next;
        }
    }
}


WorkerThread::~WorkerThread()
{
    if (result != NULL)
        pmh_free_elements(result);
    content = QString::null;
}
void WorkerThread::run()
{
    if (content.isNull())
        return;
    QByteArray ba = content.toUtf8();
    char *content_cstring = strdup((char *)ba.data());
    pmh_markdown_to_elements(content_cstring, pmh_EXT_NONE, &result);
    convertOffsets(result, content);
}




HGMarkdownHighlighter::HGMarkdownHighlighter(QTextDocument *parent,
                                             double aWaitInterval) : QObject(parent)
{
    highlightingStyles = NULL;
    workerThread = NULL;
    cached_elements = NULL;
    _makeLinksClickable = false;
    styleParsingErrorList = new QList<QPair<int, QString> >();
    _waitIntervalMilliseconds = (int)(aWaitInterval*1000);
    timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(_waitIntervalMilliseconds);
    connect(timer, SIGNAL(timeout()), this, SLOT(timerTimeout()));
    document = parent;
    beginListeningForContentChanged();

    this->parse();
}

HGMarkdownHighlighter::~HGMarkdownHighlighter()
{
    delete styleParsingErrorList;
    delete timer;
}

void HGMarkdownHighlighter::setStyles(QVector<HighlightingStyle> &styles)
{
    this->highlightingStyles = &styles;
}

double HGMarkdownHighlighter::waitInterval()
{
    return ((double)this->_waitIntervalMilliseconds)/1000.0;
}
void HGMarkdownHighlighter::setWaitInterval(double value)
{
    this->_waitIntervalMilliseconds = (int)(value*1000);
    timer->setInterval(_waitIntervalMilliseconds);
}

bool HGMarkdownHighlighter::makeLinksClickable()
{
    return _makeLinksClickable;
}
void HGMarkdownHighlighter::setMakeLinksClickable(bool value)
{
    _makeLinksClickable = value;
}


void HGMarkdownHighlighter::beginListeningForContentChanged()
{
    connect(document, SIGNAL(contentsChange(int,int,int)),
            this, SLOT(handleContentsChange(int,int,int)));
}
void HGMarkdownHighlighter::stopListeningForContentChanged()
{
    disconnect(this, SLOT(handleContentsChange(int,int,int)));
}


void HGMarkdownHighlighter::setColors(QString primaryColor, QString secondaryColor, QString highlightColor, QString secondaryHighlightColor)
{
    m_primaryColor = QString(primaryColor);
    m_secondaryColor = QString(secondaryColor);
    m_highlightColor = QString(highlightColor);
    m_secondaryHighlightColor = QString(secondaryHighlightColor);

}

#define STY(type, format) styles->append((HighlightingStyle){type, format})
void HGMarkdownHighlighter::setDefaultStyles()
{
    QVector<HighlightingStyle> *styles = new QVector<HighlightingStyle>();

    QTextCharFormat header1; header1.setForeground(QBrush(QColor(m_highlightColor)));
    //header1.setBackground(QBrush(QColor(178,178,207)));
    header1.setFontWeight(QFont::Bold);
    STY(pmh_H1, header1);

    QTextCharFormat header2; header2.setForeground(QBrush(QColor(m_highlightColor)));
    //header2.setBackground(QBrush(QColor(204,204,227)));
    header2.setFontWeight(QFont::Bold);
    STY(pmh_H2, header2);

    QTextCharFormat smallerHeaders; smallerHeaders.setForeground(QBrush(QColor(m_highlightColor)));
    //smallerHeaders.setBackground(QBrush(QColor(230,230,240)));
    STY(pmh_H3, smallerHeaders);
    STY(pmh_H4, smallerHeaders);
    STY(pmh_H5, smallerHeaders);
    STY(pmh_H6, smallerHeaders);

    QTextCharFormat hrule; hrule.setForeground(QBrush(Qt::darkGray));
    //hrule.setBackground(QBrush(Qt::lightGray));
    STY(pmh_HRULE, hrule);

    QTextCharFormat list; list.setForeground(QBrush(QColor(m_highlightColor)));
    STY(pmh_LIST_BULLET, list);
    STY(pmh_LIST_ENUMERATOR, list);

    QTextCharFormat link; link.setForeground(QBrush(QColor(m_secondaryColor)));
    //link.setBackground(QBrush(QColor(237,241,242)));
    STY(pmh_LINK, link);
    STY(pmh_AUTO_LINK_URL, link);
    STY(pmh_AUTO_LINK_EMAIL, link);

    QTextCharFormat image; image.setForeground(QBrush(QColor(m_secondaryColor)));
    //image.setBackground(QBrush(Qt::cyan));
    STY(pmh_IMAGE, image);

    QTextCharFormat ref; ref.setForeground(QBrush(QColor(m_secondaryHighlightColor)));
    STY(pmh_REFERENCE, ref);

    QTextCharFormat code; code.setForeground(QBrush(QColor(m_secondaryHighlightColor)));
    //code.setBackground(QBrush(QColor(235,242,235)));
    STY(pmh_CODE, code);
    STY(pmh_VERBATIM, code);

    QTextCharFormat emph; emph.setForeground(QBrush(QColor(m_primaryColor)));
    emph.setFontItalic(true);
    STY(pmh_EMPH, emph);

    QTextCharFormat strong; strong.setForeground(QBrush(QColor(m_primaryColor)));
    strong.setFontWeight(QFont::Bold);
    STY(pmh_STRONG, strong);

    QTextCharFormat comment; comment.setForeground(QBrush(QColor(m_secondaryColor)));
    STY(pmh_COMMENT, comment);

    QTextCharFormat blockquote; blockquote.setForeground(QBrush(QColor(m_secondaryColor)));
    STY(pmh_BLOCKQUOTE, blockquote);

    this->setStyles(*styles);
}

QColor colorFromARGBStyle(pmh_attr_argb_color *color)
{
    QColor qcolor;
    qcolor.setAlpha(color->alpha);
    qcolor.setRed(color->red);
    qcolor.setGreen(color->green);
    qcolor.setBlue(color->blue);
    return qcolor;
}

QBrush brushFromARGBStyle(pmh_attr_argb_color *color)
{
    return QBrush(colorFromARGBStyle(color));
}

QString HGMarkdownHighlighter::availableFontFamilyFromPreferenceList(QString familyList)
{
    QStringList preferredFamilies = familyList.split(',', QString::SkipEmptyParts);

    QFontDatabase fontDB;
    QStringList availableFamilies = fontDB.families();

    foreach (QString familyPreference, preferredFamilies)
    {
        QString trimmedPref = familyPreference.trimmed().toLower();
        // Docs say: If a family exists in several foundries, the returned
        // name for that font is in the form "family [foundry]".
        // Examples: "Times [Adobe]", "Times [Cronyx]", "Palatino".
        foreach (QString availableFamily, availableFamilies)
        {
            QString trimmedAvailableFamily(availableFamily);
            int foundryNameStartIndex = trimmedAvailableFamily.lastIndexOf("[");
            if (foundryNameStartIndex != -1)
                trimmedAvailableFamily = trimmedAvailableFamily.left(foundryNameStartIndex);
            trimmedAvailableFamily = trimmedAvailableFamily.trimmed().toLower();
            if (trimmedAvailableFamily == trimmedPref)
                return availableFamily;
        }
    }

    return QString::null;
}


QTextCharFormat getCharFormatFromStyleAttributes(pmh_style_attribute *list,
                                                 QFont baseFont)
{
    QTextCharFormat format;
    while (list != NULL)
    {
        if (list->type == pmh_attr_type_foreground_color)
            format.setForeground(brushFromARGBStyle(list->value->argb_color));
        else if (list->type == pmh_attr_type_background_color)
            format.setBackground(brushFromARGBStyle(list->value->argb_color));
        //else if (list->type == pmh_attr_type_caret_color) {} // TODO
        else if (list->type == pmh_attr_type_font_style)
        {
            if (list->value->font_styles->bold)
                format.setFontWeight(QFont::Bold);
            if (list->value->font_styles->italic)
                format.setFontItalic(true);
            if (list->value->font_styles->underlined)
                format.setUnderlineStyle(QTextCharFormat::SingleUnderline);
        }
        else if (list->type == pmh_attr_type_font_size_pt)
        {
            qreal finalSize = list->value->font_size->size_pt;
            int baseFontSize = baseFont.pointSize();
            if (baseFontSize == -1)
                baseFontSize = 12; // fallback default
            if (list->value->font_size->is_relative)
                finalSize += baseFontSize;
            if (0 < finalSize)
                format.setFontPointSize(finalSize);
        }
        else if (list->type == pmh_attr_type_font_family)
        {
            QString familyList(list->value->font_family);
            QString availableFamily = HGMarkdownHighlighter::availableFontFamilyFromPreferenceList(familyList);
            if (!availableFamily.isNull())
                format.setFontFamily(availableFamily);
        }
        list = list->next;
    }
    return format;
}

QPalette getDefaultPlainTextEditPalette()
{
    static bool hasBeenCached = false;
    static QPalette palette;
    if (!hasBeenCached)
    {
        QPlainTextEdit *pte = new QPlainTextEdit();
        palette = pte->palette();
        delete pte;
        hasBeenCached = true;
    }
    return palette;
}


void styleParserErrorCallback(char *error_message, int line_number, void *context)
{
    ((HGMarkdownHighlighter*)context)->handleStyleParsingError(error_message,
                                                               line_number);
}

void HGMarkdownHighlighter::handleStyleParsingError(char *error_message,
                                                    int line_number)
{
    styleParsingErrorList->append(QPair<int,QString>(
                                      line_number,
                                      QString(error_message)));
}

bool HGMarkdownHighlighter::getStylesFromStylesheet(QString filePath, QPlainTextEdit *editor)
{
    QString stylesheet;
    QFile file(filePath);
    if (file.open(QIODevice::ReadOnly)) {
        QTextStream stream(&file);
        stylesheet = stream.readAll();
    }
    QByteArray arr = stylesheet.toUtf8();
    const char *stylesheet_cstring = arr.data();

    QVector<HighlightingStyle> *styles = new QVector<HighlightingStyle>();

    styleParsingErrorList->clear();
    pmh_style_collection *raw_styles = pmh_parse_styles((char *)stylesheet_cstring,
                                                        &styleParserErrorCallback,
                                                        this);
    bool errorsFound = (0 < styleParsingErrorList->count());

    // Set language element styles
    styles->clear();
    for (int i = 0; i < pmh_NUM_LANG_TYPES; i++)
    {
        pmh_style_attribute *cur = raw_styles->element_styles[i];
        if (cur == NULL)
            continue;
        pmh_element_type lang_element_type = cur->lang_element_type;
        QTextCharFormat format = getCharFormatFromStyleAttributes(cur, editor->font());
        STY(lang_element_type, format);
    }

    this->setStyles(*styles);

    // Set editor styles
    if (editor != NULL)
    {
        QPalette palette = getDefaultPlainTextEditPalette();

        // Editor area styles
        if (raw_styles->editor_styles != NULL)
        {
            pmh_style_attribute *cur = raw_styles->editor_styles;
            while (cur != NULL)
            {
                if (cur->type == pmh_attr_type_background_color)
                    palette.setColor(QPalette::Base, colorFromARGBStyle(cur->value->argb_color));
                else if (cur->type == pmh_attr_type_foreground_color)
                    palette.setColor(QPalette::Text, colorFromARGBStyle(cur->value->argb_color));
                cur = cur->next;
            }
        }

        // Selection styles
        if (raw_styles->editor_selection_styles != NULL)
        {
            pmh_style_attribute *cur = raw_styles->editor_selection_styles;
            while (cur != NULL)
            {
                if (cur->type == pmh_attr_type_background_color)
                    palette.setColor(QPalette::Highlight, colorFromARGBStyle(cur->value->argb_color));
                else if (cur->type == pmh_attr_type_foreground_color)
                    palette.setColor(QPalette::HighlightedText, colorFromARGBStyle(cur->value->argb_color));
                cur = cur->next;
            }
        }

        // Current line styles (not applied; simply stored into a public
        // ivar so that someone else can read it from there)
        if (raw_styles->editor_current_line_styles != NULL)
        {
            pmh_style_attribute *cur = raw_styles->editor_current_line_styles;
            while (cur != NULL)
            {
                if (cur->type == pmh_attr_type_background_color)
                    currentLineHighlightColor = colorFromARGBStyle(cur->value->argb_color);
                cur = cur->next;
            }
        }
        else
            currentLineHighlightColor = QColor();

        editor->setPalette(palette);
    }

    pmh_free_style_collection(raw_styles);

    if (errorsFound)
        emit styleParsingErrors(styleParsingErrorList);
    return errorsFound;
}

void HGMarkdownHighlighter::clearFormatting()
{
    QTextBlock block = document->firstBlock();
    while (block.isValid())
    {
        block.layout()->clearAdditionalFormats();
        block = block.next();
    }
}

void HGMarkdownHighlighter::highlight()
{
    if (cached_elements == NULL) {
//        Logger::warning("cached_elements is NULL");
        return;
    }

    if (highlightingStyles == NULL)
        this->setDefaultStyles();

    this->clearFormatting();

    // QTextDocument::characterCount returns a value one higher than the
    // actual character count.
    // See: https://bugreports.qt.nokia.com//browse/QTBUG-4841
    // document->toPlainText().length() would give us the correct value
    // but it's probably too slow.
    unsigned long max_offset = document->characterCount() - 1;

    for (int i = 0; i < highlightingStyles->size(); i++)
    {
        HighlightingStyle style = highlightingStyles->at(i);
        pmh_element *elem_cursor = cached_elements[style.type];
        while (elem_cursor != NULL)
        {
            unsigned long pos = elem_cursor->pos;
            unsigned long end = elem_cursor->end;

            if (end <= pos || max_offset < pos)
            {
                elem_cursor = elem_cursor->next;
                continue;
            }

            if (max_offset < end)
                end = max_offset;

            // "The QTextLayout object can only be modified from the
            // documentChanged implementation of a QAbstractTextDocumentLayout
            // subclass. Any changes applied from the outside cause undefined
            // behavior." -- we are breaking this rule here. There might be
            // a better (more correct) way to do this.

            int startBlockNum = document->findBlock(pos).blockNumber();
            int endBlockNum = document->findBlock(end).blockNumber();
            for (int j = startBlockNum; j <= endBlockNum; j++)
            {
                QTextBlock block = document->findBlockByNumber(j);

                QTextLayout *layout = block.layout();
                QList<QTextLayout::FormatRange> list = layout->additionalFormats();
                int blockpos = block.position();
                QTextLayout::FormatRange r;
                r.format = style.format;

                if (_makeLinksClickable
                    && (elem_cursor->type == pmh_LINK
                        || elem_cursor->type == pmh_AUTO_LINK_URL
                        || elem_cursor->type == pmh_AUTO_LINK_EMAIL
                        || elem_cursor->type == pmh_REFERENCE)
                    && elem_cursor->address != NULL)
                {
                    QString address(elem_cursor->address);
                    if (elem_cursor->type == pmh_AUTO_LINK_EMAIL && !address.startsWith("mailto:"))
                        address = "mailto:" + address;
                    QTextCharFormat linkFormat(r.format);
                    linkFormat.setAnchor(true);
                    linkFormat.setAnchorHref(address);
                    linkFormat.setToolTip(address);
                    r.format = linkFormat;
                }

                if (j == startBlockNum) {
                    r.start = pos - blockpos;
                    r.length = (startBlockNum == endBlockNum)
                                ? end - pos
                                : block.length() - r.start;
                } else if (j == endBlockNum) {
                    r.start = 0;
                    r.length = end - blockpos;
                } else {
                    r.start = 0;
                    r.length = block.length();
                }

                list.append(r);
                layout->setAdditionalFormats(list);
            }

            elem_cursor = elem_cursor->next;
        }
    }

    document->markContentsDirty(0, document->characterCount());
}

void HGMarkdownHighlighter::parse()
{
    if (workerThread != NULL && workerThread->isRunning()) {
        parsePending = true;
        return;
    }

    if (workerThread != NULL)
        delete workerThread;
    workerThread = new WorkerThread();
    workerThread->content = document->toPlainText();
    connect(workerThread, SIGNAL(finished()), this, SLOT(threadFinished()));
    parsePending = false;
    workerThread->start();
}

void HGMarkdownHighlighter::threadFinished()
{
    if (parsePending) {
        this->parse();
        return;
    }

    if (cached_elements != NULL)
        pmh_free_elements(cached_elements);
    cached_elements = workerThread->result;
    workerThread->result = NULL;

    this->highlight();
}

void HGMarkdownHighlighter::handleContentsChange(int position, int charsRemoved,
                                                 int charsAdded)
{
    Q_UNUSED(position);
    if (charsRemoved == 0 && charsAdded == 0)
        return;

    //Logger::debug("contents changed. chars removed/added:" + charsRemoved + " " + charsAdded);

    timer->stop();
    timer->start();
}

void HGMarkdownHighlighter::timerTimeout()
{
    this->parse();
}

void HGMarkdownHighlighter::highlightNow()
{
    highlight();
}

void HGMarkdownHighlighter::parseAndHighlightNow()
{
    parse();
}

