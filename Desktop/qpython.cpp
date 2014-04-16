#include "qpython.h"


#include <QtQml>
#include <QDir>
#include <QFile>

#ifndef MAXPATHLEN
#if defined(PATH_MAX) && PATH_MAX > 1024
#define MAXPATHLEN PATH_MAX
#else
#define MAXPATHLEN 1024
#endif
#endif /* MAXPATHLEN */
//#include <QResource>

int
QPython::instances = 0;

static PyThreadState *ptsGlobal = NULL;

/* Given a (sub)modulename, write the potential file path in the
   archive (without extension) to the path buffer. Return the
   length of the resulting string. */
static int
make_filename(char *prefix, char *name, char *path)
{
    size_t len;
    char *p;

    len = strlen(prefix);

    /* self.prefix + name [+ SEP + "__init__"] + ".py[co]" */
    if (len + strlen(name) + 13 >= MAXPATHLEN) {
        PyErr_SetString(PyExc_ImportError, "path too long");
        return -1;
    }

    strcpy(path, prefix);
    strcpy(path + len, name);
    for (p = path + len; *p; p++) {
        if (*p == '.')
            *p = '/';
    }
    len += strlen(name);
    assert(len < INT_MAX);
    return (int)len;
}

char *
myotherside_search_module(char *fullpath, char *path) {

    QDir res(":/");

    qDebug() << fullpath;
    qDebug() << path;

    return NULL;
}

PyObject *
myotherside_find_module(PyObject *self, PyObject *args) {

    char *fullname, *path;
    int err = PyArg_ParseTuple(args, "s|z", &fullname, &path);

    qDebug() << self;
    if(err == 0)
    {
        PyObject_Print(PyErr_Occurred(), stdout, Py_PRINT_RAW);
        PySys_WriteStdout("\n");
        PyErr_Print();
        PySys_WriteStdout("\n");
    }

    //myotherside_search_module(fullname, path);

    QString filename(fullname);
    filename = ":/python/"+filename+".py";
    qDebug() << filename;
    QFile file(filename);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return Py_None;
    } else {
        qDebug() << self;
        Py_INCREF(self);
        return self;
    }
}

PyObject *
myotherside_load_module(PyObject *self, PyObject *args) {

    qDebug() << "pyotherside_load_module called";

    const char *module_source;
    char *fullname;
    PyArg_ParseTuple(args, "s", &fullname);
    PyObject *mod, *dict;
    PyObject *module_code;

    mod = PyImport_AddModule(fullname);
    if (mod == NULL) {
        return NULL;
    }

    QString filename(fullname);
    filename = ":/"+filename+".py";
    QFile moduleContent(filename);

    if(moduleContent.open(QIODevice::ReadOnly | QIODevice::Text)) {
        module_source = moduleContent.readAll().constData();

        if(module_source == NULL) {
            //We couldnt load the module. Raise ImportError
            Py_RETURN_NONE;
        }

        // Compile module code
        module_code = Py_CompileString(module_source, fullname, Py_file_input);
        if (module_code == NULL){
            //Can't compile the module
            Py_RETURN_NONE;
        }
        // Set the __loader__ object to pyotherside module
        dict = PyModule_GetDict(mod);
        if (PyDict_SetItemString(dict, "__loader__", (PyObject *)self) != 0)
            Py_RETURN_NONE;

        // Import the compiled code module
        mod = PyImport_ExecCodeModuleEx(fullname, module_code, fullname);

        Py_DECREF(dict);

        return mod;
    }
    Py_RETURN_NONE;
}

static PyMethodDef MyOtherSideMethods[] = {
    {"find_module", myotherside_find_module, METH_VARARGS},
    {"load_module", myotherside_load_module, METH_VARARGS},
    {NULL, NULL, 0, NULL},
};

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
    PyObject *myotherside = Py_InitModule("myotherside", MyOtherSideMethods);

    PyGILState_STATE state = PyGILState_Ensure();

//    PyImport_AppendInittab("myotherside", initMyOtherSide);
/*    Py_InitModule3("mypyotherside", MyOtherSideMethods,
               "Module Mecanichs to import module from qrc package");
*/

    PyObject *meta_path = PySys_GetObject("meta_path");
    if (meta_path != NULL)
    {
        PyList_Append(meta_path, myotherside);
    }

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

/* return fullname.split(".")[-1] */
static char *
get_subname(char *fullname)
{
    char *subname = strrchr(fullname, '.');
    if (subname == NULL)
        subname = fullname;
    else
        subname++;
    return subname;
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

    //Does module is in qrc ?

    //QFile data(":/python/"+moduleName+".py"); ???

    /*
        std::string filename = std::string("embedded:") + module_name;
        PyObject *pCompiledCodeObject = Py_CompileString( source, filename.c_str(), Py_file_input );

        if( !pCompiledCodeObject )
        LOG_PRINT_ERROR( "Py_CompileString() returned NULL." );

        // Copy the module name because PyImport_ExecCodeModule does not accept const char *
        const int max_module_name_length = 256;
        char module_name_copy[max_module_name_length];
        memset( module_name_copy, 0, sizeof(module_name_copy) );
        strcpy( module_name_copy, module_name );

        PyObject *pModule = PyImport_ExecCodeModule( module_name_copy, pCompiledCodeObject );

        if( !pModule )
        LOG_PRINT_ERROR( "PyImport_ExecCodeModule() returned NULL." );

        */


    PyObject *module = PyImport_ImportModule(moduleName);
    if (module == NULL) {
        PyObject *ptype, *pvalue, *ptraceback, *pstring;
        PyErr_Fetch(&ptype, &pvalue, &ptraceback);
        PyErr_Clear();
        char *excstring;
        char *valuestring;
        pstring=PyObject_Str(ptype);
        if (ptype != NULL && pstring !=NULL &&
            (PyString_Check(pstring)))
          excstring = PyString_AsString(pstring);
        else
          excstring = (char *)"<unknown exception type> ";
        Py_XDECREF(pstring);
        pstring=PyObject_Str(pvalue);
        if (ptype != NULL && pstring !=NULL &&
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
        pstring=PyObject_Str(ptype);
        if (ptype != NULL && pstring !=NULL &&
            (PyString_Check(pstring)))
          excstring = PyString_AsString(pstring);
        else
          excstring = (char *)"<unknown exception type> ";
        Py_XDECREF(pstring);
        pstring=PyObject_Str(pvalue);
        if (ptype != NULL && pstring !=NULL &&
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
            pstring=PyObject_Str(ptype);
            if (ptype != NULL && pstring !=NULL &&
                (PyString_Check(pstring)))
              excstring = PyString_AsString(pstring);
            else
              excstring = (char *)"<unknown exception type> ";
            Py_XDECREF(pstring);
            pstring=PyObject_Str(pvalue);
            if (ptype != NULL && pstring !=NULL &&
                (PyString_Check(pstring)))
              valuestring = PyString_AsString(pstring);
            else
              valuestring = (char *)"";
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
    } else if (v.canConvert(QMetaType::QString)) {
        QByteArray utf8bytes = v.toString().toUtf8();
        return PyUnicode_FromString(utf8bytes.constData());
    }

    qDebug() << "XXWX Qt -> Python converstion not handled yet 2";

    return NULL;
}

/*PyMODINIT_FUNC
initMyOtherSide()
{
    Py_InitModule3("mypyotherside", MyOtherSideMethods,
               "Module Mecanichs to import module from qrc package");
}*/
