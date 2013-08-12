#include "qpython.h"

#include <QtDeclarative>

int
QPython::instances = 0;

static
PyThreadState *ptsGlobal = NULL;


QPython::QPython(QObject *parent)
    : QObject(parent)
    , locals(PyDict_New())
    , globals(PyDict_New())
{
    if (instances == 0) {
        Py_Initialize();
        PyEval_InitThreads();
        ptsGlobal = PyEval_SaveThread();
        watchers = * new QList<QFutureWatcher<QVariant> *> ();
        futures = * new QList<QFuture<QVariant> > ();

    }


    instances++;

    PyGILState_STATE state = PyGILState_Ensure();
    if (PyDict_GetItemString(globals, "__builtins__") == NULL) {
        PyDict_SetItemString(globals, "__builtins__",
                PyEval_GetBuiltins());
    }
    PyGILState_Release (state);
}

QPython::~QPython()
{
    instances--;
    if (instances == 0) {
        PyEval_AcquireLock();
        PyThreadState_Swap(ptsGlobal);

        Py_Finalize();
    }
}

void
QPython::addImportPath(QString path)
{
    QByteArray utf8bytes = path.toUtf8();

    PyGILState_STATE state = PyGILState_Ensure();
    PyObject *sys_path = PySys_GetObject((char *)"path");
    PyObject *cwd = PyString_FromString(utf8bytes.constData());
    PyList_Insert(sys_path, 0, cwd);
    Py_DECREF(cwd);
    PyGILState_Release (state);
}

bool
QPython::importModule(QString name)
{
    // Lesson learned: name.toUtf8().constData() doesn't work, as the
    // temporary QByteArray will be destroyed after constData() has
    // returned, so we need to save the toUtf8() result in a local
    // variable that doesn't get destroyed until the function returns.
    QByteArray utf8bytes = name.toUtf8();
    const char *moduleName = utf8bytes.constData();

    PyGILState_STATE state = PyGILState_Ensure();
    PyObject *module = PyImport_ImportModule(moduleName);
    if (module == NULL) {
        PyObject *ptype, *pvalue, *ptraceback, *pstring;
        PyErr_Fetch(&ptype, &pvalue, &ptraceback);
        PyErr_Clear();
        char *excstring;
        char *valuestring;
        if (ptype != NULL && (pstring=PyObject_Str(ptype))!=NULL &&
            (PyString_Check(pstring)))
          excstring = PyString_AsString(pstring);
        else
          excstring = (char *)"<unknown exception type> ";
        Py_XDECREF(pstring);
        if (pvalue != NULL && (pstring=PyObject_Str(pvalue))!=NULL &&
            (PyString_Check(pstring)))
          valuestring = PyString_AsString(pstring);
        else
          valuestring = (char *)"";
        Py_XDECREF(pstring);
        emit exception(QString::fromUtf8(excstring),
                       QString::fromUtf8(valuestring));
        PyGILState_Release (state);
        return false;
    }

    PyDict_SetItemString(globals, moduleName, module);
    PyGILState_Release (state);
    return true;
}

QVariant
QPython::evaluate(QString expr)
{
    PyGILState_STATE state = PyGILState_Ensure();
    PyObject *o = eval(expr);
    QVariant v = fromPython(o);
    Py_DECREF(o);
    PyGILState_Release (state);
    return v;
}

PyObject *
QPython::eval(QString expr)
{
    QByteArray utf8bytes = expr.toUtf8();
    PyGILState_STATE state = PyGILState_Ensure();
    PyObject *result = PyRun_String(utf8bytes.constData(),
            Py_eval_input, globals, locals);

    if (result == NULL) {
        PyObject *ptype, *pvalue, *ptraceback, *pstring;
        PyErr_Fetch(&ptype, &pvalue, &ptraceback);
        PyErr_Clear();
        char *excstring;
        char *valuestring;
        if (ptype != NULL && (pstring=PyObject_Str(ptype))!=NULL &&
            (PyString_Check(pstring)))
          excstring = PyString_AsString(pstring);
        else
          excstring = (char *)"<unknown exception type> ";
        Py_XDECREF(pstring);
        if (pvalue != NULL && (pstring=PyObject_Str(pvalue))!=NULL &&
            (PyString_Check(pstring)))
          valuestring = PyString_AsString(pstring);
        else
          valuestring = (char *)"";
        Py_XDECREF(pstring);
        emit exception(QString::fromUtf8(excstring),
                       QString::fromUtf8(valuestring));
    }
    PyGILState_Release (state);
    return result;
}

void QPython::threadedCall(QString func, QVariant args)
{

    QFutureWatcher<QVariant> *watcher = new QFutureWatcher<QVariant>();
    watchers.append(watcher);
    QFuture<QVariant> future = QtConcurrent::run<QVariant>(this, &QPython::call, func, args);

    futures.append(future);

    connect(watcher, SIGNAL(finished()),
               this, SLOT(threadedCallFinished()));
    connect(watcher, SIGNAL(resultReadyAt(int)),
               this, SLOT(threadedCallResultReady(int)));

    watcher->setFuture(future);
}

void
QPython::threadedCallFinished()
{
    emit finished();
}

void

QPython::threadedCallResultReady(int index)
{
    for (int i = futures.size() - 1 ; i >= 0; --i) {
        if (futures[i].resultCount() > index) {
            if (futures[i].isResultReadyAt(index)) {
                QVariant result = futures[i].resultAt(index);
                if (result != QVariant())
                    emit message(result);
                futures.removeAt(i); // Remove the watchers and future from the QList
                watchers.removeAt(i); // As we have only one result, and we don't want to access it again.
            }
        }
    }
}

QVariant
QPython::call(QString func, QVariant args)
{

    // Ensure Python GIL State
    PyGILState_STATE state = PyGILState_Ensure();

    PyObject *callable = eval(func);

    if (callable == NULL) {
        PyGILState_Release(state);
        return QVariant();
    }

    if (PyCallable_Check(callable)) {
        QVariant v;

        PyObject *argl = toPython(args);
        assert(PyList_Check(argl));
        PyObject *argt = PyList_AsTuple(argl);
        Py_DECREF(argl);
        PyObject *o = PyObject_Call(callable, argt, NULL);
        Py_DECREF(argt);

        if (o == NULL) {
            //PyErr_Print();
            //Get error message and send a signal
            PyObject *ptype, *pvalue, *ptraceback, *pstring;
            PyErr_Fetch(&ptype, &pvalue, &ptraceback);
            PyErr_Clear();
            char *excstring;
            char *valuestring;
            if (ptype != NULL && (pstring=PyObject_Str(ptype))!=NULL &&
                (PyString_Check(pstring)))
              excstring = PyString_AsString(pstring);
            else
              excstring = "<unknown exception type> ";
            Py_XDECREF(pstring);
            if (pvalue != NULL && (pstring=PyObject_Str(pvalue))!=NULL &&
                (PyString_Check(pstring)))
              valuestring = PyString_AsString(pstring);
            else
              valuestring = "";
            Py_XDECREF(pstring);
            emit exception(QString::fromUtf8(excstring),
                           QString::fromUtf8(valuestring));
            v = QVariant();

        } else {
            v = fromPython(o);
            Py_DECREF(o);
        }

        Py_DECREF(callable);
        // Release GIL
        PyGILState_Release(state);

        return v;
    }

    qDebug() << "Not a callable:" << func;
    Py_DECREF(callable);
    // Release GIL
    PyGILState_Release(state);

    return QVariant();
}


void
QPython::registerQML()
{
    qmlRegisterType<QPython>("net.khertan.python", 1, 0, "Python");
}

QVariant
QPython::fromPython(PyObject *o)
{
    if (PyInt_Check(o)) {
        return QVariant((int)PyInt_AsLong(o));
    } else if (PyBool_Check(o)) {
        return QVariant(o == Py_True);
    } else if (PyLong_Check(o)) {
        return QVariant((qlonglong)PyLong_AsLong(o));
    } else if (PyFloat_Check(o)) {
        return QVariant(PyFloat_AsDouble(o));
    } else if (PyList_Check(o)) {
        QVariantList result;

        Py_ssize_t count = PyList_Size(o);
        for (int i=0; i<count; i++) {
            result << fromPython(PyList_GetItem(o, i));
        }

        return result;
    } else if (PyUnicode_Check(o)) {
        PyObject *string = PyUnicode_AsUTF8String(o);
        QVariant result = fromPython(string);
        Py_DECREF(string);
        return result;
    } else if (PyString_Check(o)) {
        // We always assume UTF-8 encoding here
        return QString::fromUtf8(PyString_AsString(o));
    } else if (PyDict_Check(o)) {
        QMap<QString,QVariant> result;

        PyObject *key, *value;
        Py_ssize_t pos = 0;
        while (PyDict_Next(o, &pos, &key, &value)) {
            result[fromPython(key).toString()] = fromPython(value);
        }

        return result;
    }

    qDebug() << "XXX Python -> Qt conversion not handled yet";
    return QVariant();
}

PyObject *
QPython::toPython(QVariant v)
{
    QVariant::Type type = v.type();

    if (type == QVariant::Bool) {
        if (v.toBool()) {
            Py_RETURN_TRUE;
        } else {
            Py_RETURN_FALSE;
        }
    } else if (type == QVariant::Int) {
        return PyLong_FromLong(v.toInt());
    } else if (type == QVariant::Double) {
        return PyFloat_FromDouble(v.toDouble());
    } else if (type == QVariant::List) {
        QVariantList l = v.toList();

        PyObject *result = PyList_New(l.size());
        for (int i=0; i<l.size(); i++) {
            PyList_SetItem(result, i, toPython(l[i]));
        }
        return result;
    } else if (type == QVariant::String) {
        QByteArray utf8bytes = v.toString().toUtf8();
        return PyUnicode_FromString(utf8bytes.constData());
    } else if (type == QVariant::Map) {
        QMap<QString,QVariant> m = v.toMap();
        QList<QString> keys = m.keys();

        PyObject *result = PyDict_New();
        for (int i=0; i<keys.size(); i++) {
            PyObject *o = toPython(m[keys[i]]);
            QByteArray utf8bytes = keys[i].toUtf8();
            PyDict_SetItemString(result, utf8bytes.constData(), o);
            Py_DECREF(o);
        }
        return result;
    }

    qDebug() << "XXX Qt -> Python converstion not handled yet";
    return NULL;
}

