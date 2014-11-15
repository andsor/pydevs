from cpython.ref cimport PyObject


ctypedef PyObject* PythonObject


cdef extern from "adevs/adevs.h" namespace "adevs":
    cdef cppclass PortValue[VALUE, PORT]:
        PortValue(PORT, const VALUE&) except +
        PORT port
        VALUE value

    cdef cppclass Bag[T]:
        cppclass iterator:
            const T& operator*() const
            iterator operator++()
            iterator operator--()
            iterator operator+(int)
            iterator operator-(int)
            bint operator==(iterator)
            bint operator!=(iterator)
        Bag() except +
        unsigned int size() const
        bint empty() const
        iterator begin() const
        iterator end() const
        void erase(const T&)
        void erase(iterator)
        void clear()
        unsigned int count(const T&) const
        iterator find(const T&) const
        void insert(const T&)


ctypedef PortValue[PythonObject, int] CPortValue
ctypedef Bag[CPortValue] IOBag
ctypedef Bag[CPortValue].iterator IOBagIterator
ctypedef double Time


ctypedef void (*DeltaIntFunc)(PyObject*)
ctypedef void (*DeltaExtFunc)(PyObject*, Time, const IOBag&)
ctypedef void (*DeltaConfFunc)(PyObject*, const IOBag&)
ctypedef void (*OutputFunc)(PyObject*, IOBag&)
ctypedef Time (*TaFunc)(PyObject*)

cdef extern from "adevs_python.hpp" namespace "pydevs":

    cdef cppclass Atomic:
        Atomic(
            PyObject*,
            DeltaIntFunc,
            DeltaExtFunc,
            DeltaConfFunc,
            OutputFunc,
            TaFunc,
        )
