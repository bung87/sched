# scheduler
# Copyright zhoupeng
# A new awesome nimble package
import rlocks
import heapqueue
import times
import os

type
    scheduler*[TArg] = object
        L: RLock
        thr:seq[Thread[TArg]]
        timefunc:proc():float
        delayfunc:proc(a:float)
        queue:HeapQueue[Event[TArg]]
    Event[TArg] = object
        time:Natural
        priority:Natural
        action:proc(a:TArg)
        args:TArg

proc `==`(s, o:Event):bool = (s.time, s.priority) == (o.time, o.priority)
proc `<`(s, o:Event):bool = (s.time, s.priority) < (o.time, o.priority)
proc `<=`(s, o:Event):bool = (s.time, s.priority) <= (o.time, o.priority)
proc `>`(s, o:Event):bool = (s.time, s.priority) > (o.time, o.priority)
proc `>=`(s, o:Event):bool = (s.time, s.priority) >= (o.time, o.priority)


proc enterabs*[TArg](self:var scheduler[TArg], time:Natural, priority:Natural, action:proc(a:TArg),args:TArg):auto =
    ##[Enter a new event in the queue at an absolute time.
    Returns an ID for the event which can be used to remove it,
    if necessary.
    ]##
    # if kwargs is _sentinel:
    #     kwargs = {}
    result = Event[TArg](time:time,priority: priority,action: action,args:args) #, argument, kwargs)
    withRLock(self.L):
        self.queue.push( result)
    # return event # The ID

proc enter*[TArg](self:var scheduler[TArg], delay:Natural, priority:Natural, action:proc(a:TArg),args:TArg):auto = #, argument=(), kwargs=_sentinel):
    ##[A variant that specifies the time as a relative time.
    This is actually the more commonly used interface.
    ]##
    let time = self.timefunc() + cast[float](delay)
    # let act = proc(a:TArg)
    result = self.enterabs(cast[Natural](time), priority, action,args) #, argument, kwargs)

proc cancel*[TArg](self:var scheduler[TArg], event:Event) =
    ##[Remove an event from the queue.
    This must be presented the ID as returned by enter().
    If the event is not in the queue, this raises ValueError.
    ]##
    withRLock(self.L):
        self.queue.del(event)
        # heapq.heapify(self.thr)

proc empty*[TArg](self:var scheduler[TArg]):bool=
    ##[Check whether the queue is empty.]##
    withRLock(self.L):
        return not self.queue

proc run*[TArg](self:var scheduler[TArg] , blocking=true)=
    ##[Execute events until the queue is empty.
    If blocking is False executes the scheduled events due to
    expire soonest (if any) and then return the deadline of the
    next scheduled call in the scheduler.
    When there is a positive delay until the first event, the
    delay function is called and the event is left in the queue;
    otherwise, the event is removed from the queue and executed
    (its action function is called, passing it the argument).  If
    the delay function returns prematurely, it is simply
    restarted.
    It is legal for both the delay function and the action
    function to modify the queue or to raise an exception;
    exceptions are not caught but the scheduler's state remains
    well-defined so run() may be called again.
    A questionable hack is added to allow other threads to run:
    just after an event is executed, a delay of 0 is executed, to
    avoid monopolizing the CPU when other threads are also
    runnable.
    ]##
    # localize variable access to minimize overhead
    # and to improve thread safety
    let lock = self.L
    let q = self.queue
    let delayfunc = self.delayfunc
    let timefunc = self.timefunc
    var 
        delay:bool
        time:float
        m_now:float
    # pop = heapq.heappop
    while true:
        withRLock(self.L):
            # if not q:
            #     break
            # time, priority, action, argument, kwargs = q[0]
            m_now = timefunc()
            if time > m_now:
                delay = true
            else:
                delay = false
                discard self.queue.pop()
        if delay:
            if not blocking:
                break
                # return time - m_now
            delayfunc(time - m_now)
        else:
            # action(*argument, **kwargs)
            delayfunc(0)   # Let other threads run

proc queue[TArg](self:var scheduler[TArg] ):HeapQueue[Event[TArg]]=
    ##[An ordered list of upcoming events.
    Events are named tuples with fields for:
        time, priority, action, arguments, kwargs
    ]##
    # Use heapq to sort the queue rather than using 'sorted(self._queue)'.
    # With heapq, two events scheduled at the same time will show in
    # the actual order they would be retrieved.
    withRLock(self.L):
        result = self.queue
    # return list(map(heapq.heappop, [events]*len(events)))

when isMainModule:
    var delay = proc(a:float) = sleep( cast[int](a) )
    var s = scheduler[string](timefunc:epochTime, delayfunc:delay)
    proc print_time(a="default") =
        echo "From print_time", epochTime()

    proc print_some_times() =
        echo epochTime()
        discard s.enter(delay:10, 1, print_time,"a")
        # discard s.enter(5, 2, print_time)#, argument=("positional",))
        # discard s.enter(5, 1, print_time)#, kwargs={'a': "keyword"})
        s.run()
        echo epochTime()

    print_some_times()
# 930343690.257
# From print_time 930343695.274 positional
# From print_time 930343695.275 keyword
# From print_time 930343700.273 default
# 930343700.276