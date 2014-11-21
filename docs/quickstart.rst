pydevs Quickstart
=================

See `Modeling and simulation with Adevs
<http://web.ornl.gov/~1qn/adevs/adevs-docs/manual/node4.html>`_ for a
comprehensive introduction into modeling and simulation with adevs/pydevs.

Here we merely demonstrate how to set up a simple DEVS network model (adevs
Digraph model) in Python.

.. code:: python

    import logging
    import devs
.. code:: python

    logger = logging.getLogger('quickstart')
    logger.setLevel(logging.DEBUG)
    #logging.getLogger('devs').setLevel(logging.WARNING)
A Source -- Processor -- Observer model (M/M/1 Queue)
-----------------------------------------------------

.. code:: python

    import collections
    import random
.. code:: python

    class Source(devs.AtomicBase):
        arrival_port = 0
        
        def __init__(self, arrival_rate=1.0, **kwds):
            super().__init__(**kwds)
            self.logger = logging.getLogger('quickstart.Source')
            self.logger.info('Initialize source with arrival rate {}'.format(arrival_rate))
            self.arrival_rate = arrival_rate
            self.inter_arrival_time = random.expovariate(self.arrival_rate)
            self.job_id = 0
            
        def ta(self):
            self.logger.debug('Next arrival in {} time units'.format(self.inter_arrival_time))                
            return self.inter_arrival_time
        
        def delta_int(self):
            self.job_id += 1
            self.inter_arrival_time = random.expovariate(self.arrival_rate)
            
        def output_func(self):
            self.logger.info('Generate job {}'.format(self.job_id))
            return self.arrival_port, self.job_id
        
        
    class Server(devs.AtomicBase):
        arrival_port = 0
        departure_port = 1
        
        def __init__(self, service_rate=1.0, **kwds):
            super().__init__(**kwds)
            self.logger = logging.getLogger('quickstart.Server')
            self.logger.info('Initialize server with service rate {}'.format(service_rate))
            self.service_rate = service_rate
            self.remaining_service_time = devs.infinity
            self.queue = collections.deque()
            self.job_in_service = None
            
        def ta(self):
            if self.job_in_service is None:
                self.logger.debug('Server is idle')
                return devs.infinity
                
            return self.remaining_service_time
        
        def start_next_job(self):
            self.job_in_service = self.queue.popleft()
            self.remaining_service_time = random.expovariate(self.service_rate)
            self.logger.info('Start processing job {} with service time {}'.format(self.job_in_service, self.remaining_service_time))
            
        def delta_int(self):
            # service finished
            self.logger.info('Finished processing job {}'.format(self.job_in_service))
            if len(self.queue):
                # jobs waiting, start to process immediately
                self.start_next_job()
            else:
                # no more jobs, switch to idle
                self.logger.info('Queue empty, server turns idle')
                self.job_in_service = None
    
        def delta_ext(self, e, xb):
            if self.job_in_service is not None:
                self.remaining_service_time -= e
                
            # new job(s) arriving
            for port, job_id in xb:
                self.logger.info('New job {} arrives'.format(job_id))
                self.queue.append(job_id)
                if self.job_in_service is None:
                    # queue empty, start immediately
                    self.start_next_job()
                else:
                    # server busy
                    self.logger.debug('Server busy, enqueueing job {}'.format(job_id))
    
            self.logger.debug('Remaining service time for job {}: {} time units'.format(self.job_in_service, self.remaining_service_time))            
                    
        def delta_conf(xb):
            # treat incoming jobs first
            self.delta_ext(self.ta(), xb)
            self.delta_int()
            
        def output_func(self):
            # service finished
            return self.departure_port, self.job_in_service
        
        
    class Observer(devs.AtomicBase):
        arrival_port = 0
        departure_port = 1
        
        def __init__(self, time=0.0, **kwds):
            super().__init__(**kwds)
            self.logger = logging.getLogger('quickstart.Observer')
            self.logger.info('Initialize observer at time {}'.format(time))
            self.time = time
            self.arrivals = list()
            self.departures = list()
            
        def delta_ext(self, e, xb):
            self.time += e
            for port, job_id in xb:
                if port == self.arrival_port:
                    self.logger.info('Job {} arrives at time {}'.format(job_id, self.time))
                    self.arrivals.append(self.time)
                elif port == self.departure_port:
                    self.logger.info('Job {} departs at time {}'.format(job_id, self.time))
                    self.departures.append(self.time)
.. code:: python

    source = Source(1.0)
    server = Server(1.0)
    observer = Observer()

.. parsed-literal::

    INFO:quickstart.Source:Initialize source with arrival rate 1.0
    INFO:quickstart.Server:Initialize server with service rate 1.0
    INFO:quickstart.Observer:Initialize observer at time 0.0


.. code:: python

    digraph = devs.Digraph()
    digraph.add(source)
    digraph.add(server)
    digraph.add(observer)
    digraph.couple(source, source.arrival_port, server, server.arrival_port)
    digraph.couple(source, source.arrival_port, observer, observer.arrival_port)
    digraph.couple(server, server.departure_port, observer, observer.departure_port)
.. code:: python

    simulator = devs.Simulator(digraph)

.. parsed-literal::

    DEBUG:quickstart.Server:Server is idle
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity
    -c:1: UserWarning: ta not implemented, return devs.infinity
    DEBUG:quickstart.Source:Next arrival in 0.1652953524349517 time units


.. code:: python

    simulator.execute_until(5.0)

.. parsed-literal::

    INFO:quickstart.Source:Generate job 0
    INFO:quickstart.Server:New job 0 arrives
    INFO:quickstart.Server:Start processing job 0 with service time 3.5509846975085804
    DEBUG:quickstart.Server:Remaining service time for job 0: 3.5509846975085804 time units
    INFO:quickstart.Observer:Job 0 arrives at time 0.1652953524349517
    DEBUG:quickstart.Source:Next arrival in 1.0903431091204843 time units
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity
    INFO:quickstart.Source:Generate job 1
    INFO:quickstart.Server:New job 1 arrives
    DEBUG:quickstart.Server:Server busy, enqueueing job 1
    DEBUG:quickstart.Server:Remaining service time for job 0: 2.4606415883880963 time units
    INFO:quickstart.Observer:Job 1 arrives at time 1.255638461555436
    DEBUG:quickstart.Source:Next arrival in 2.3049818738267307 time units
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity
    INFO:quickstart.Source:Generate job 2
    INFO:quickstart.Server:New job 2 arrives
    DEBUG:quickstart.Server:Server busy, enqueueing job 2
    DEBUG:quickstart.Server:Remaining service time for job 0: 0.15565971456136563 time units
    INFO:quickstart.Observer:Job 2 arrives at time 3.5606203353821666
    DEBUG:quickstart.Source:Next arrival in 2.937090534560785 time units
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity
    INFO:quickstart.Server:Finished processing job 0
    INFO:quickstart.Server:Start processing job 1 with service time 0.9782561195217124
    INFO:quickstart.Observer:Job 0 departs at time 3.7162800499435322
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity
    INFO:quickstart.Server:Finished processing job 1
    INFO:quickstart.Server:Start processing job 2 with service time 0.404069818122655
    INFO:quickstart.Observer:Job 1 departs at time 4.694536169465245
    WARNING:devs.devs.AtomicBase:ta not implemented, return devs.infinity


.. code:: python

    observer.arrivals, observer.departures



.. parsed-literal::

    ([0.1652953524349517, 1.255638461555436, 3.5606203353821666],
     [3.7162800499435322, 4.694536169465245])



.. code:: python

    logger.setLevel(logging.ERROR)
    logging.getLogger('devs').setLevel(logging.ERROR)
.. code:: python

    simulator.execute_until(100000.0)
.. code:: python

    len(observer.arrivals), len(observer.departures), len(server.queue)



.. parsed-literal::

    (100015, 99697, 317)



