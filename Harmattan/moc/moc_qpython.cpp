/****************************************************************************
** Meta object code from reading C++ file 'qpython.h'
**
** Created: Mon 12. Aug 16:47:45 2013
**      by: The Qt Meta Object Compiler version 62 (Qt 4.7.4)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../qpython.h"
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'qpython.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 62
#error "This file was generated using the moc from 4.7.4. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

QT_BEGIN_MOC_NAMESPACE
static const uint qt_meta_data_QPython[] = {

 // content:
       5,       // revision
       0,       // classname
       0,    0, // classinfo
      10,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       3,       // signalCount

 // signals: signature, parameters, type, tag, flags
       9,    8,    8,    8, 0x05,
      25,   20,    8,    8, 0x05,
      53,   43,    8,    8, 0x05,

 // slots: signature, parameters, type, tag, flags
      80,    8,    8,    8, 0x0a,
     109,  103,    8,    8, 0x0a,

 // methods: signature, parameters, type, tag, flags
     143,  138,    8,    8, 0x02,
     176,  171,  166,    8, 0x02,
     212,  207,  198,    8, 0x02,
     240,  230,  198,    8, 0x02,
     263,  230,    8,    8, 0x02,

       0        // eod
};

static const char qt_meta_stringdata_QPython[] = {
    "QPython\0\0finished()\0data\0message(QVariant)\0"
    "type,data\0exception(QString,QString)\0"
    "threadedCallFinished()\0index\0"
    "threadedCallResultReady(int)\0path\0"
    "addImportPath(QString)\0bool\0name\0"
    "importModule(QString)\0QVariant\0expr\0"
    "evaluate(QString)\0func,args\0"
    "call(QString,QVariant)\0"
    "threadedCall(QString,QVariant)\0"
};

const QMetaObject QPython::staticMetaObject = {
    { &QObject::staticMetaObject, qt_meta_stringdata_QPython,
      qt_meta_data_QPython, 0 }
};

#ifdef Q_NO_DATA_RELOCATION
const QMetaObject &QPython::getStaticMetaObject() { return staticMetaObject; }
#endif //Q_NO_DATA_RELOCATION

const QMetaObject *QPython::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->metaObject : &staticMetaObject;
}

void *QPython::qt_metacast(const char *_clname)
{
    if (!_clname) return 0;
    if (!strcmp(_clname, qt_meta_stringdata_QPython))
        return static_cast<void*>(const_cast< QPython*>(this));
    return QObject::qt_metacast(_clname);
}

int QPython::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: finished(); break;
        case 1: message((*reinterpret_cast< const QVariant(*)>(_a[1]))); break;
        case 2: exception((*reinterpret_cast< const QString(*)>(_a[1])),(*reinterpret_cast< const QString(*)>(_a[2]))); break;
        case 3: threadedCallFinished(); break;
        case 4: threadedCallResultReady((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 5: addImportPath((*reinterpret_cast< QString(*)>(_a[1]))); break;
        case 6: { bool _r = importModule((*reinterpret_cast< QString(*)>(_a[1])));
            if (_a[0]) *reinterpret_cast< bool*>(_a[0]) = _r; }  break;
        case 7: { QVariant _r = evaluate((*reinterpret_cast< QString(*)>(_a[1])));
            if (_a[0]) *reinterpret_cast< QVariant*>(_a[0]) = _r; }  break;
        case 8: { QVariant _r = call((*reinterpret_cast< QString(*)>(_a[1])),(*reinterpret_cast< QVariant(*)>(_a[2])));
            if (_a[0]) *reinterpret_cast< QVariant*>(_a[0]) = _r; }  break;
        case 9: threadedCall((*reinterpret_cast< QString(*)>(_a[1])),(*reinterpret_cast< QVariant(*)>(_a[2]))); break;
        default: ;
        }
        _id -= 10;
    }
    return _id;
}

// SIGNAL 0
void QPython::finished()
{
    QMetaObject::activate(this, &staticMetaObject, 0, 0);
}

// SIGNAL 1
void QPython::message(const QVariant _t1)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)) };
    QMetaObject::activate(this, &staticMetaObject, 1, _a);
}

// SIGNAL 2
void QPython::exception(const QString _t1, const QString _t2)
{
    void *_a[] = { 0, const_cast<void*>(reinterpret_cast<const void*>(&_t1)), const_cast<void*>(reinterpret_cast<const void*>(&_t2)) };
    QMetaObject::activate(this, &staticMetaObject, 2, _a);
}
QT_END_MOC_NAMESPACE
