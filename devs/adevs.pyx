from cpython.ref cimport PyObject, Py_XINCREF, Py_CLEAR
cimport cython.operator as co
cimport cadevs


ctypedef cadevs.PythonObject PythonObject
ctypedef cadevs.Time Time
ctypedef cadevs.Port Port
ctypedef cadevs.CPortValue CPortValue
ctypedef cadevs.IOBag CIOBag
ctypedef cadevs.IOBagIterator CIOBagIterator
ctypedef cadevs.CDevs CDevs
ctypedef cadevs.Components CComponents
ctypedef cadevs.ComponentsIterator CComponentsIterator


cdef class IOBag:
    """
    Python extension base type that wraps an existing C++ I/O bag

    For constant bags, only the internal pointer _thisconstptr is used.
    For non-const bags, both internal pointers _thisconstptr and _thisptr are
    used.
    """
    cdef CIOBag* _thisptr
    cdef const CIOBag* _thisconstptr
    cdef bint _is_const

    cpdef unsigned int size(self):
        return self._thisconstptr.size()

    cpdef bint empty(self):
        return self._thisconstptr.empty()

    def __iter__(self):
        """
        Generator to iterate over elements in bag

        http://docs.python.org/3/library/stdtypes.html#generator-types

        Return (port, value) tuples upon each iteration
        """

        # get first and last element
        cdef CIOBagIterator it = self._thisconstptr.begin()
        cdef CIOBagIterator end = self._thisconstptr.end()

        cdef const CPortValue* pv

        while it != end:
            pv = &co.dereference(it)
            yield pv.port, <object>(pv.value)
            co.preincrement(it)


cdef object CreateOutputBag(CIOBag* bag):
    """
    Create a new Python object output bag wrapped around an existing C++ I/O
    bag
    http://stackoverflow.com/a/12205374/2366781
    """
    output_bag = OutputBag()
    output_bag._thisptr = bag
    output_bag._thisconstptr = bag
    output_bag._is_const = False
    return output_bag


cdef class OutputBag(IOBag):
    """
    Python extension type that wraps an existing C++ I/O bag

    To construct an instance in Cython, use the CreateOutputBag factory
    function.

    When inserting port/values, increase the reference counter for Python
    objects.
    """

    cpdef insert(self, int port, object value):
        pyobj = <PythonObject>value
        self._thisptr.insert(CPortValue(port, pyobj))
        Py_XINCREF(pyobj)


cdef object CreateInputBag(const CIOBag* bag):
    """
    Create a new Python object input bag wrapped around an existing C++ I/O bag
    http://stackoverflow.com/a/12205374/2366781
    """
    input_bag = InputBag()
    input_bag._thisconstptr = bag
    input_bag._is_const = True
    return input_bag


cdef class InputBag(IOBag):
    """
    Python extension type that wraps an existing C++ I/O bag
    """
    pass


cdef class AtomicBase:
    """
    Python extension type, base type for DEVS Atomic Model

    Python modules subclass this type and overwrite the methods

    How does it work?
    -----------------

    When initialized, the constructor (__init__) creates a new instance
    of the underlying C++ wrapper class Atomic (defined in the C++ header
    file).
    The C++ wrapper class Atomic inherits from adevs::Atomic and implements
    all the virtual functions.
    The C++ wrapper instance receives the function pointers to the cy_*
    helper functions defined here, as well as a pointer to the Python extension
    type instance.
    Whenever adevs calls one of the virtual functions of the C++ wrapper
    instance, the C++ wrapper instance routes it via the function pointer to
    the corresponding cy_* helper function.
    The cy_* helper function calls the corresponding method of the instance of
    the Python extension type.

    http://stackoverflow.com/a/12700121/2366781
    https://bitbucket.org/binet/cy-cxxfwk/src


    Reference counting
    ------------------

    When initialized, the constructor (__init__) creates a new instance of the
    underlying C++ wrapper class Atomic (defined in the C++ header file).
    The C++ wrapper class Atomic increases the reference count to this Python
    object, and decreases the reference count upon destruction.
    So the Python object will exist at least as long as the C++ wrapper
    instance exists.
    Hence, it is safe to delete the C++ instance when this Python object is
    destroyed.
    When adevs deletes the C++ wrapper instance, the Python object is not
    deleted, when it is still referenced in the Python scope, but we can live
    with that.


    Input/output
    ------------
    The port type is integer.
    The value type is a generic Python object.
    This Python wrapper class abstracts away the underlying adevs C++ PortValue
    type.

    adevs creates (copies) the C++ PortValue instance.
    https://github.com/smiz/adevs/blob/aae196ba660259ac32fc254bad810f4b4185d52f/include/adevs_digraph.h#L194
    https://github.com/smiz/adevs/blob/aae196ba660259ac32fc254bad810f4b4185d52f/include/adevs_bag.h#L156

    The only interface we need is to iterate over input (InputBag) in delta_ext
    and delta_conf, and to add output events (OutputBag) in output_func.
    Adding output events, the instance of this Python wrapper class increases
    the reference counter of the value Python object.
    The C++ wrapper class decreases the reference counter upon adevs' call to
    the gc_output garbage collection function.
    """

    cdef cadevs.Atomic* base_ptr_

    def __init__(self):
        self.base_ptr_ = new cadevs.Atomic(
            <PyObject*>self,
            <cadevs.DeltaIntFunc>cy_delta_int,
            <cadevs.DeltaExtFunc>cy_delta_ext,
            <cadevs.DeltaConfFunc>cy_delta_conf,
            <cadevs.OutputFunc>cy_output_func,
            <cadevs.TaFunc>cy_ta,
        )

    def __dealloc__(self):
        del self.base_ptr_

    def delta_int(self):
        pass

    def delta_ext(self, Time e, InputBag xb):
        pass

    def delta_conf(self, InputBag xb):
        pass

    def output_func(self, OutputBag yb):
        pass

    def ta(self):
        pass


cdef void cy_delta_int(PyObject* object):
    cdef AtomicBase atomic_base = <AtomicBase>(object)
    atomic_base.delta_int()


cdef void cy_delta_ext(
    PyObject* object, cadevs.Time e, const cadevs.IOBag& xb
):
    cdef AtomicBase atomic_base = <AtomicBase>(object)

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef InputBag input_bag = CreateInputBag(&xb)

    atomic_base.delta_ext(e, input_bag)


cdef void cy_delta_conf(
    PyObject* object, const cadevs.IOBag& xb
):
    cdef AtomicBase atomic_base = <AtomicBase>(object)

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef InputBag input_bag = CreateInputBag(&xb)

    atomic_base.delta_conf(input_bag)


cdef void cy_output_func(
    PyObject* object, cadevs.IOBag& yb
):
    cdef AtomicBase atomic_base = <AtomicBase>(object)

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef OutputBag output_bag = CreateOutputBag(&yb)

    atomic_base.output_func(output_bag)


cdef Time cy_ta(
    PyObject* object
):
    cdef AtomicBase atomic_base = <AtomicBase>(object)

    return atomic_base.ta()


cdef class Digraph:
    """
    Python extension type that wraps the C++ wrapper class for the adevs
    Digraph class

    Design decision
    ---------------
    For now, we only provide Atomic models.
    I.e. nested network models are not supported yet.

    Memory management
    -----------------
    An instance of the C++ Digraph class takes ownership of added components,
    i.e. deletes the components at the end of its lifetime.
    https://github.com/smiz/adevs/blob/aae196ba660259ac32fc254bad810f4b4185d52f/include/adevs_digraph.h#L205
    """
    cdef cadevs.Digraph* _thisptr

    def __cinit__(self):
        self._thisptr = new cadevs.Digraph()

    def __dealloc__(self):
        del self._thisptr

    cpdef add(self, AtomicBase model):
        self._thisptr.add(model.base_ptr_)

    cpdef couple(
        self,
        AtomicBase source, Port source_port,
        AtomicBase destination, Port destination_port,
    ):
        self._thisptr.couple(
            source.base_ptr_, source_port,
            destination.base_ptr_, destination_port,
        )

    def __iter__(self):
        """
        Generator to iterate over components of the digraph

        http://docs.python.org/3/library/stdtypes.html#generator-types

        Return AtomicBase Python objects upon each iteration
        """

        cdef CComponents components
        self._thisptr.getComponents(components)

        # get first and last element
        cdef CComponentsIterator it = components.begin()
        cdef CComponentsIterator end = components.end()

        cdef cadevs.Atomic* component

        while it != end:
            component = <cadevs.Atomic*>(&co.dereference(it))
            yield <object>(component.get_python_object())
            co.preincrement(it)
