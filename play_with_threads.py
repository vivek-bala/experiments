import radical.pilot as rp
import radical.utils as ru
import threading
import Queue
import time

doneQ = Queue.Queue()
num_tasks = 5

def create_tasks(tid, v1, v2):
    print 'Thread {0} creating task {1}\n'.format(tid, v2)
    
    cud = rp.ComputeUnitDescription()
    cud.name = "{0}_{1}".format(int(v1)+1, v2)
    cud.executable = '/bin/echo'
    cud.arguments = ["{0}_{1}".format(int(v1)+1, v2)]

    return cud

class ExecuteThread(threading.Thread):

    def __init__(self, q1):
        threading.Thread.__init__(self)
        self._q1 = q1
        self._logger = ru.get_logger('radical.entk.thread')

    def run(self):

        while True:
            val = self._q1.get()
            v1,v2 = val.split('_')
            task = create_tasks(self.getName(), v1, v2)

            print 'Created cu: {0}'.format(task.name)

            self._q1.task_done()


def unit_cb(unit, state):

    if ((unit.state == rp.DONE) or (unit.state == rp.CANCELED)):
        doneQ.put(unit.name)


if __name__ == '__main__':


    # RP stuff
    session = rp.Session()

    try:

        # Add a Pilot Manager. Pilot managers manage one or more ComputePilots.
        pmgr = rp.PilotManager(session=session)

        # Define an [n]-core local pilot that runs for [x] minutes
        # Here we use a dict to initialize the description object
        pd_init = {
                'resource'      : 'local.localhost',
                'runtime'       : 10,  # pilot runtime (min)
                'cores'         : 2,
                }
        pdesc = rp.ComputePilotDescription(pd_init)

        # Launch the pilot.
        pilot = pmgr.submit_pilots(pdesc)

        # Register the ComputePilot in a UnitManager object.
        umgr = rp.UnitManager(session=session)
        umgr.add_pilots(pilot)

        umgr.register_callback(unit_cb)

        cuds = list()

        for i in range(1, num_tasks+1):

            # create a new CU description, and fill it.
            # Here we don't use dict initialization.
            cud = rp.ComputeUnitDescription()
            cud.executable = '/bin/echo'
            cud.name = "1_{0}".format(i)
            cud.arguments = ["1_{0}".format(i)]

            print 'Created cu: {0}'.format(cud.name)

            cuds.append(cud)

        cus = umgr.submit_units(cuds)

        # Thread stuff
        t1 = ExecuteThread(doneQ)
        #t1.setDaemon(True)
        t1.start()

        uids = [cu.uid for cu in cus]
        umgr.wait_units(uids)

        print 'Tasks done'
        print 'Q size: {0}'.format(doneQ.qsize())

        doneQ.join()

        print 'Q done'

    except Exception, ex:

        print 'Error: ',ex

    finally:

        print 'Closing session'
        session.close(cleanup=False)