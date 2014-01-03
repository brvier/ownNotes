#ifndef HIGHLIGHTER_H
#define HIGHLIGHTER_H

#include <QtGui/QTextCharFormat>
#include <QtCore/QThread>
#include <QtCore/QPair>
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QWidget>
#include <QtGui/QPalette>

extern "C" {
#include "pmh_parser.h"
}

QT_BEGIN_NAMESPACE
class QTextDocument;
QT_END_NAMESPACE

class WorkerThread : public QThread
{
public:
    ~WorkerThread();
    void run();
    QString content;
    pmh_element **result;
};

struct HighlightingStyle
{
    pmh_element_type type;
    QTextCharFormat format;
};


class HGMarkdownHighlighter : public QObject
{
    Q_OBJECT

public:
    HGMarkdownHighlighter(QTextDocument *parent = 0, double aWaitInterval = 1);
    ~HGMarkdownHighlighter();
    QColor currentLineHighlightColor;
    QList<QPair<int, QString> > *styleParsingErrorList;

    void highlightNow();
    void parseAndHighlightNow();

    void setStyles(QVector<HighlightingStyle> &styles);
    bool getStylesFromStylesheet(QString filePath, QPlainTextEdit *editor);

    double waitInterval();
    void setWaitInterval(double value);
    bool makeLinksClickable();
    void setMakeLinksClickable(bool value);

    void handleStyleParsingError(char *error_message, int line_number);

    static QString availableFontFamilyFromPreferenceList(QString familyList);
    void setColors(QString primaryColor, QString secondaryColor, QString highlightColor, QString secondaryHighlightColor);

signals:
    void styleParsingErrors(QList<QPair<int, QString> > *errors);

protected:
    void beginListeningForContentChanged();
    void stopListeningForContentChanged();

private slots:
    void handleContentsChange(int position, int charsRemoved, int charsAdded);
    void threadFinished();
    void timerTimeout();

private:
    bool _makeLinksClickable;
    int _waitIntervalMilliseconds;
    QTimer *timer;
    QTextDocument *document;
    WorkerThread *workerThread;
    bool parsePending;
    pmh_element **cached_elements;
    QVector<HighlightingStyle> *highlightingStyles;
    QString cachedContent;

    QString m_primaryColor;
    QString m_secondaryColor;
    QString m_highlightColor;
    QString m_secondaryHighlightColor;

    void clearFormatting();
    void highlight();
    void parse();
    void setDefaultStyles();

};

#endif
