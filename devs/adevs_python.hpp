/*

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

*/

#ifndef ADEVS_PYTHON_HPP
#define ADEVS_PYTHON_HPP

#include <functional>

#include <Python.h>

#include "adevs.h"



namespace pydevs {



typedef PyObject* Value;
typedef int Port;
typedef adevs::PortValue<Value, Port> PortValue;
typedef adevs::Bag<PortValue> IOBag;
typedef double Time;
typedef adevs::Atomic<PortValue, Time> AtomicBase;
typedef adevs::Digraph<Value, Port, Time> DigraphBase;
typedef adevs::Devs<PortValue, Time> Devs;
typedef adevs::Simulator<PortValue, Time> SimulatorBase;

typedef void (*DeltaIntFunc)(PyObject*);
typedef void (*DeltaExtFunc)(PyObject*, Time, const IOBag&);
typedef void (*DeltaConfFunc)(PyObject*, const IOBag&);
typedef void (*OutputFunc)(PyObject*, IOBag&);
typedef Time (*TaFunc)(PyObject*);



/**
 *	C++ wrapper class which implements the virtual functions
 *	of the adevs Atomic model
*/
class Atomic: public AtomicBase {

public:

	explicit Atomic(
		PyObject* pythonObject,
		DeltaIntFunc deltaIntFunc,
		DeltaExtFunc deltaExtFunc,
		DeltaConfFunc deltaConfFunc,
		OutputFunc outputFunc,
		TaFunc taFunc
	)
	: 	AtomicBase(),
		pythonObject_ (pythonObject),
		deltaIntFunc_ (deltaIntFunc),
		deltaExtFunc_ (deltaExtFunc),
		deltaConfFunc_ (deltaConfFunc),
		outputFunc_ (outputFunc),
		taFunc_ (taFunc)
	{ }	



	/**
	 * Destructor
	 */
	virtual ~Atomic() { }



	virtual void delta_int() {

		bool isDefined = this->pythonObject_ && this->deltaIntFunc_;
		if (isDefined)
			this->deltaIntFunc_ (this->pythonObject_);
		else
			throw std::bad_function_call();

	}



	virtual void delta_ext (Time e, const IOBag& xb) {

		bool isDefined = this->pythonObject_ && this->deltaExtFunc_;
		if (isDefined)
			this->deltaExtFunc_ (
				this->pythonObject_, e, xb
			);
		else
			throw std::bad_function_call();

	}



	virtual void delta_conf (const IOBag& xb) {

		bool isDefined = this->pythonObject_ && this->deltaConfFunc_;
		if (isDefined)
			this->deltaConfFunc_ (
				this->pythonObject_, xb
			);
		else
			throw std::bad_function_call();

	}



	virtual void output_func (IOBag& yb) {

		bool isDefined = this->pythonObject_ && this->outputFunc_;
		if (isDefined)
			this->outputFunc_ (
				this->pythonObject_, yb
			);
		else
			throw std::bad_function_call();

	}



	virtual Time ta() {

		bool isDefined = this->pythonObject_ && this->taFunc_;
		if (isDefined)
			return this->taFunc_ (this->pythonObject_);
		else
			throw std::bad_function_call();

	}



	/*
		garbage collection
		
		Decrease reference counters of all Python objects
	*/
	virtual void gc_output (IOBag& g) {

		for (auto& portValue : g) {
			Py_CLEAR (portValue.value);
		}

	}



	PyObject* getPythonObject() const {

		return this->pythonObject_;

	}



private:

	PyObject* const pythonObject_;
	const DeltaIntFunc deltaIntFunc_;
	const DeltaExtFunc deltaExtFunc_;
	const DeltaConfFunc deltaConfFunc_;
	const OutputFunc outputFunc_;
	const TaFunc taFunc_;

};



/**
 * C++ wrapper class for Digraph
 */
class Digraph {

public:

	typedef adevs::Set<Devs*> Components;



	/*
		Constructor
	*/
	explicit Digraph() : base_() {}



	DigraphBase& getBase() {

		return this->base_;

	}



	/**
	 * Add a DEVS model to the Digraph
	 *
	 * Currently, only atomic models are implemented.
	 */
	void add (Atomic* model) {

		this->base_.add (model);

	}



	/**
	 * Couple components
	 *
	 * Currently, only atomic models are implemented.
	 */
	void couple(
		Atomic* source, Port source_port, 
		Atomic* destination, Port destination_port
	)
	{

		this->base_.couple(
			source, source_port,
			destination, destination_port
		);

	}



	void getComponents (Components& components) {

		this->base_.getComponents (components);

	}
	


private:

	DigraphBase base_;

};



/**
 *  C++ wrapper class for Simulator
 */
class Simulator {

public:

	/**
	 * Constructors
	 */
	explicit Simulator (Devs* model) : base_(model) {}



	explicit Simulator (Atomic* model) : base_(model) {}



	explicit Simulator (Digraph* digraph)
	: base_ (&digraph->getBase())
	{}



	SimulatorBase& getBase() {

		return this->base_;

	}



	Time nextEventTime() {

		return this->base_.nextEventTime();

	}



	void executeNextEvent() {

		this->base_.execNextEvent();

	}



	void executeUntil (Time tEnd) {

		this->base_.execUntil (tEnd);

	}



private:

	SimulatorBase base_;

};



} // namespace pydevs



# endif // ADEVS_PYTHON_HPP
