'''

   Copyright 2014 The pydevs Developers

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

'''

from cpython.ref cimport PyObject, Py_INCREF, Py_XINCREF, Py_CLEAR, Py_DECREF
cimport cython.operator as co
cimport cadevs
import logging
import sys
import warnings

logger = logging.getLogger(__name__)

ctypedef cadevs.PythonObject PythonObject
ctypedef cadevs.Time Time
ctypedef cadevs.Port Port
ctypedef cadevs.CPortValue CPortValue
ctypedef cadevs.IOBag CIOBag
ctypedef cadevs.IOBagIterator CIOBagIterator
ctypedef cadevs.CDevs CDevs
ctypedef cadevs.Components CComponents
ctypedef cadevs.ComponentsIterator CComponentsIterator

infinity = sys.float_info.max


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
    Upon adding the model to a Digraph, the Digraph increases the reference
    count to this Python object, and decreases the reference count upon
    destruction.
    Note that the adevs C++ Digraph instance assumes ownership of the C++
    wrapper instances.
    The C++ Digraph instance deletes all C++ wrapper instances upon destruction.
    So the Python object might still exist even though the C++ wrapper
    instance is long gone.
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

    We deliberately break the adevs interface for the output_func method.
    In adevs, a reference to a Bag is supplied to the method returning void.
    Here, we choose the Pythonic way and take the return value of the method as
    the output bag.
    This is converted automatically by the cy_output_func helper function.
    output_func can either return
        None (no output),
        a tuple (of length 2: port, value),
        or an iterable (of tuples of length 2: port, value).
    For example, output_func can be implemented as a generator expression.

    Similarly, the cy_delta_ext and cy_delta_conf helper functions convert the
    input bag to a Python list of port, value tuples.
    """

    cdef cadevs.Atomic* base_ptr_
    cdef object _logger

    def __cinit__(self, *args, **kwargs):
        logger.debug('Initialize AtomicBase (__cinit__)...')
        self.base_ptr_ = new cadevs.Atomic(
            <PyObject*>self,
            <cadevs.DeltaIntFunc>cy_delta_int,
            <cadevs.DeltaExtFunc>cy_delta_ext,
            <cadevs.DeltaConfFunc>cy_delta_conf,
            <cadevs.OutputFunc>cy_output_func,
            <cadevs.TaFunc>cy_ta,
        )
        logger.debug('Initialized AtomicBase (__cinit__).')
        logger.debug('Set up logging for new AtomicBase instance...')
        self._logger = logging.getLogger(__name__ + '.AtomicBase')
        self._logger.debug('Set up logging.')

    def __dealloc__(self):
        if self.base_ptr_ is NULL:
            logger.debug('AtomicBase: Internal pointer already cleared.')
        else:
            logger.debug('AtomicBase: Deallocate internal pointer...')
            del self.base_ptr_
            logger.debug('AtomicBase: Deallocated internal pointer.')

    def _reset_base_ptr(self):
        self._logger.debug('Reset internal pointer')
        self.base_ptr_ = NULL

    def delta_int(self):
        warn_msg = 'delta_int not implemented'
        self._logger.warning(warn_msg)
        warnings.warn(warn_msg)

    def delta_ext(self, e, xb):
        warn_msg = 'delta_ext not implemented'
        self._logger.warning(warn_msg)
        warnings.warn(warn_msg)

    def delta_conf(self, xb):
        warn_msg = 'delta_conf not implemented'
        self._logger.warning(warn_msg)
        warnings.warn(warn_msg)

    def output_func(self):
        warn_msg = 'output_func not implemented, return None'
        self._logger.warning(warn_msg)
        warnings.warn(warn_msg)
        return None

    def ta(self):
        warn_msg = 'ta not implemented, return devs.infinity'
        self._logger.warning(warn_msg)
        warnings.warn(warn_msg)
        return infinity


cdef void cy_delta_int(PyObject* object) except *:
    logger.debug('Cython delta_int helper function')
    cdef AtomicBase atomic_base = <AtomicBase>object
    atomic_base.delta_int()


cdef void cy_delta_ext(
    PyObject* object, cadevs.Time e, const cadevs.IOBag& xb
) except *:
    logger.debug('Cython delta_ext helper function')
    cdef AtomicBase atomic_base = <AtomicBase>object

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef InputBag input_bag = CreateInputBag(&xb)

    atomic_base.delta_ext(e, list(input_bag))


cdef void cy_delta_conf(
    PyObject* object, const cadevs.IOBag& xb
) except *:
    logger.debug('Cython delta_conf helper function')
    cdef AtomicBase atomic_base = <AtomicBase>object

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef InputBag input_bag = CreateInputBag(&xb)

    atomic_base.delta_conf(list(input_bag))


cdef void cy_output_func(
    PyObject* object, cadevs.IOBag& yb
) except *:
    logger.debug('Cython output_func helper function')
    cdef AtomicBase atomic_base = <AtomicBase>object

    # wrap the C++ Bag in a Python Wrapper Bag class
    cdef OutputBag output_bag = CreateOutputBag(&yb)

    output = atomic_base.output_func()

    if output is None:
        logger.debug('output_func returns None')
        return

    if type(output) is tuple:
        logger.debug('output_func returns tuple')
        if len(output) != 2:
            err_msg = (
                'output_func needs to return tuple of length 2, got length {}'
            ).format(len(output))
            logger.error(err_msg)
            raise ValueError(err_msg)
        output_bag.insert(output[0], output[1])
        return

    try:
        iterator = iter(output)
    except TypeError:
        raise ValueError

    for port, value in output:
        output_bag.insert(port, value)


cdef Time cy_ta(
    PyObject* object
) except *:
    logger.debug('Cython ta helper function')
    cdef AtomicBase atomic_base = <AtomicBase>object

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
    This is why we increase the reference count to the Python object as soon as
    we add it to the Digraph.
    Upon deletion of the Digraph, the reference count is decreased.
    https://github.com/smiz/adevs/blob/aae196ba660259ac32fc254bad810f4b4185d52f/include/adevs_digraph.h#L205
    """
    cdef cadevs.Digraph* _thisptr
    cdef object logger

    def __cinit__(self):
        logger.debug('Initialize Digraph...')
        self._thisptr = new cadevs.Digraph()
        logger.debug('Initialized Digraph.')

    def __init__(self):
        logger.debug('Set up logging for new Digraph instance...')
        self.logger = logging.getLogger(__name__ + '.Digraph')
        self.logger.debug('Set up logging.')

    def __dealloc__(self):
        self.logger.debug('Temporarily store the Python objects')
        components = list(self)
        self.logger.debug('Deallocate internal pointer...')
        # this deletes all C++ Atomic models (and in turn, the references to
        # the Python objects)
        del self._thisptr
        self.logger.debug('Deallocated internal pointer.')
        self.logger.debug('Decrease reference counts of all Python objects')
        for component in components:
            Py_DECREF(component)
            component._reset_base_ptr()

    cpdef add(self, AtomicBase model):
        self.logger.debug('Add model...')
        self.logger.debug('Increase reference counter to Python object')
        Py_INCREF(model)
        self._thisptr.add(model.base_ptr_)
        self.logger.debug('Added model.')

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

        self.logger.debug("Start iteration")
        cdef CComponents components
        self._thisptr.getComponents(components)

        # get first and last element
        cdef CComponentsIterator it = components.begin()
        cdef CComponentsIterator end = components.end()

        cdef cadevs.Atomic* component
        cdef PyObject* c_python_object
        cdef object python_object

        while it != end:
            self.logger.debug("Retrieve next component")
            component = <cadevs.Atomic*>(co.dereference(it))
            self.logger.debug("Get C Python object")
            c_python_object = <PyObject*>(component.getPythonObject())
            self.logger.debug("Cast to Python object")
            python_object = <object>c_python_object
            self.logger.debug("Yield Python object")
            yield python_object
            self.logger.debug("Increment iterator")
            co.preincrement(it)

        self.logger.debug("Stop iteration")


cdef class Simulator:
    """
    Python extension type that wraps the adevs C++ Simulator class

    Memory management
    -----------------
    Note that the adevc C++ Simulator class does not assume ownership of the
    model.
    Hence, when using a Python wrapper Simulator instance, we need to keep
    the Python wrapper Digraph or AtomicBase-subclassed instance in scope as
    well.
    When the model Python instance goes out of scope, the internal C++ pointer
    gets deleted, rendering the Simulator defunct.
    """
    cdef cadevs.Simulator* _thisptr
    cdef object logger
    cdef object sim_logger

    def __cinit__(self):
        pass

    def __init__(self, object model):
        logger.debug('Initialize Simulator...')

        if isinstance(model, AtomicBase):
            if type(model) is AtomicBase:
                error_msg = (
                    'Model is AtomicBase instance, use a subclass instead'
                )
                logger.error(error_msg)
                raise TypeError(error_msg)
            logger.debug('Initialize Simulator with atomic model')
            self._thisptr = new cadevs.Simulator((<AtomicBase>model).base_ptr_)
            logger.info('Initialized Simulator with atomic model')
        elif isinstance(model, Digraph):
            logger.debug('Initialize Simulator with digraph')
            self._thisptr = new cadevs.Simulator((<Digraph>model)._thisptr)
            logger.info('Initialized Simulator with digraph')
        else:
            raise TypeError

        self.logger = logging.getLogger(__name__ + '.Simulator')
        self.logger.debug('Set up logging.')

    def __dealloc__(self):
        self.logger.debug('Deallocate internal pointer...')
        del self._thisptr
        self.logger.debug('Deallocated internal pointer.')

    def next_event_time(self):
        self.logger.debug('Compute time of next event')
        return self._thisptr.nextEventTime()

    def execute_next_event(self):
        self.logger.info('Execute next event')
        self._thisptr.executeNextEvent()

    def execute_until(self, Time t_end):
        self.logger.info('Execute until time {}'.format(t_end))
        self._thisptr.executeUntil(t_end)


logger.debug('devs imported.')
