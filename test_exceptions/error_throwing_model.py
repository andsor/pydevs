import logging
import devs

for logger_name in ('quickstart', 'devs.devs', 'devs.devs.Simulator'):
    logger = logging.getLogger(logger_name)
    logger.setLevel(logging.DEBUG)

    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger.addHandler(ch)


import collections
import random

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
#        raise ValueError("Arbitrary Error in ta()")
        return self.inter_arrival_time

    def delta_int(self):
#        if random.random() > 0.5:
#            raise ValueError("Arbitrary Error in delta_int")

        self.job_id += 1
        self.inter_arrival_time = random.expovariate(self.arrival_rate)

    def output_func(self):
        self.logger.info('Generate job {}'.format(self.job_id))
#        if random.random() > 0.5:
        raise ValueError("Arbitrary Error in Source output_func")
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
        if random.random() > 0.5:
            raise ValueError("Arbitrary Error in delta_ext")

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


source = Source(1.0)
server = Server(1.0)
observer = Observer()

digraph = devs.Digraph()
digraph.add(source)
digraph.add(server)
digraph.add(observer)
digraph.couple(source, source.arrival_port, server, server.arrival_port)
digraph.couple(source, source.arrival_port, observer, observer.arrival_port)
digraph.couple(server, server.departure_port, observer, observer.departure_port)

simulator = devs.Simulator(digraph)
try:
    simulator.execute_until(15.0)
except Exception as e:
    x = e
