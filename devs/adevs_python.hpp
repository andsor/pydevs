#include <functional>
#include "Python.h"
#include "adevs/adevs.h"

namespace pydevs {
	typedef adevs::PortValue<PyObject*> PortValue;
	typedef adevs::Bag<PortValue> IOBag;
	typedef double Time;
	typedef adevs::Atomic<PortValue, Time> AtomicBase;

	typedef void (*DeltaIntFunc)(PyObject*);
	typedef void (*DeltaExtFunc)(PyObject*, Time, const IOBag&);
	typedef void (*DeltaConfFunc)(PyObject*, const IOBag&);
	typedef void (*OutputFunc)(PyObject*, IOBag&);
	typedef Time (*TaFunc)(PyObject*);

	class Atomic: public AtomicBase {
	public:
		Atomic(
			PyObject* object,
			DeltaIntFunc delta_int_func,
			DeltaExtFunc delta_ext_func,
			DeltaConfFunc delta_conf_func,
			OutputFunc output_func,
			TaFunc ta_func
		)
		: 	AtomicBase(),
			object_(object),
			delta_int_func_(delta_int_func),
			delta_ext_func_(delta_ext_func),
			delta_conf_func_(delta_conf_func),
			output_func_(output_func),
			ta_func_(ta_func)
		{
			Py_XINCREF(this->object_);
		}

		virtual ~Atomic() {
			Py_CLEAR(this->object_);
		}

		virtual void delta_int() {
			if(!(this->object_ && this->delta_int_func_)) {
				throw std::bad_function_call();
			}
			this->delta_int_func_(this->object_);
		}

		virtual void delta_ext(Time e, const IOBag& xb) {
			if(!(this->object_ && this->delta_ext_func_)) {
				throw std::bad_function_call();
			}
			this->delta_ext_func_(this->object_, e, xb);
		}
	
		virtual void delta_conf(const IOBag& xb) {
			if(!(this->object_ && this->delta_conf_func_)) {
				throw std::bad_function_call();
			}
			this->delta_conf_func_(this->object_, xb);
		}

		virtual void output_func(IOBag& yb) {
			if(!(this->object_ && this->output_func_)) {
				throw std::bad_function_call();
			}
			this->output_func_(this->object_, yb);
		}

		virtual Time ta() {
			if(!(this->object_ && this->ta_func_)) {
				throw std::bad_function_call();
			}
			return this->ta_func_(this->object_);
		}

		/*
			garbage collection
			
			Decrease reference counters of all Python objects
		*/
		virtual void gc_output(IOBag& g) {
			for (auto& portvalue : g) {
				Py_CLEAR(portvalue.value);
			}
		}

	private:
		PyObject* object_;
		DeltaIntFunc delta_int_func_;
		DeltaExtFunc delta_ext_func_;
		DeltaConfFunc delta_conf_func_;
		OutputFunc output_func_;
		TaFunc ta_func_;
	};
}
