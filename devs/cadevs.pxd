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

    cdef cppclass Set[T]:
        cppclass iterator:
            const T& operator*() const
            iterator operator++()
            bint operator==(iterator)
            bint operator!=(iterator)
        iterator begin() const
        iterator end() const

    cdef cppclass Devs[X, T]:
        pass



ctypedef int Port
ctypedef PortValue[PythonObject, Port] CPortValue
ctypedef Bag[CPortValue] IOBag
ctypedef Bag[CPortValue].iterator IOBagIterator
ctypedef double Time
ctypedef Devs[CPortValue, Time] CDevs
ctypedef Set[CDevs*] Components
ctypedef Set[CDevs*].iterator ComponentsIterator

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
        ) except +
        PyObject* getPythonObject()

    cdef cppclass Digraph:
        Digraph() except +
        void add (Atomic*) except *
        void couple (Atomic*, Port, Atomic*, Port) except *
        void getComponents (Components&) except *

    cdef cppclass Simulator:
        Simulator(CDevs*) except +
        Simulator(Atomic*) except +
        Simulator(Digraph*) except +
        Time nextEventTime() except *
        void executeNextEvent() except *
        void executeUntil(Time) except *
