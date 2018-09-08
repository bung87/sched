# scheduler
# Copyright zhoupeng
# A new awesome nimble package
import rlocks
import heapqueue
import times
import os
import options

type
    Scheduler*[TArg] = object
        L: RLock
        thr:seq[Thread[TArg]]
        timefunc:proc():Natural
        delayfunc:proc(a:Natural)
        queue:HeapQueue[Event[TArg]]
    Event[TArg] = object
        time:Natural
        priority:Natural
        action:proc(a:TArg)
        args:TArg

const
    defaultDelayProc = proc(a:Natural) =  sleep( a * 1000 )
    defaultTimeProc = proc():Natural= epochTime().toInt()

proc initScheduler*[TArg](timefunc=defaultTimeProc, delayfunc=defaultDelayProc):Scheduler[TArg]  =
    result.timefunc = timefunc
    result.delayfunc = delayfunc
    result.queue = newHeapQueue[Event[TArg]]()
    result.L = RLock()
    initRLock(result.L)

proc `==`*[T](s, o:Event[T]):bool = (s.time, s.priority) == (o.time, o.priority)
proc `<`*[T](s, o:Event[T]):bool = (s.time, s.priority) < (o.time, o.priority)
proc `<=`*[T](s, o:Event[T]):bool = (s.time, s.priority) <= (o.time, o.priority)
proc `>`*[T](s, o:Event[T]):bool = (s.time, s.priority) > (o.time, o.priority)
proc `>=`*[T](s, o:Event[T]):bool = (s.time, s.priority) >= (o.time, o.priority)

proc enterabs*[TArg](self:var Scheduler[TArg], time:Natural, priority:Natural, action:proc(a:TArg),args:TArg):auto =
    ##[Enter a new event in the queue at an absolute time.
    Returns an ID for the event which can be used to remove it,
    if necessary.
    ]##
    result = Event[TArg](time:time,priority: priority,action: action,args:args) #, argument, kwargs)
    withRLock(self.L):
        self.queue.push( result)
    # return event # The ID

proc enter*[TArg](self:var Scheduler[TArg], delay:Natural, priority:Natural, action:proc(a:TArg),args:TArg):auto = #, argument=(), kwargs=_sentinel):
    ##[A variant that specifies the time as a relative time.
    This is actually the more commonly used interface.
    ]##        
    let time = self.timefunc() + delay
    result = self.enterabs(time, priority, action,args) #, argument, kwargs)

proc cancel*[TArg](self:var Scheduler[TArg], event:Event) =
    ##[Remove an event from the queue.
    This must be presented the ID as returned by enter().
    If the event is not in the queue, this raises ValueError.
    ]##
    withRLock(self.L):
        self.queue.del(event)
        # heapq.heapify(self.thr)

proc empty*[TArg](self:var Scheduler[TArg]):bool=
    ##[Check whether the queue is empty.]##
    withRLock(self.L):
        return self.queue.len == 0

proc toSortedSeq*[T](h: HeapQueue[T]): seq[T] =
    var tmp = h
    result = @[]
    while tmp.len > 0:
        result.add(pop(tmp))

proc run*[TArg](self:var Scheduler[TArg] , blocking=true):Option[int]=
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
    let q = self.queue
    let delayfunc = self.delayfunc
    let timefunc = self.timefunc
    var 
        delay:bool
        time:Natural
        first:Event[TArg]
    # pop = heapq.heappop
    while true:
        acquire(self.L)
        if q.len == 0:
            break
        # time, priority, action, argument, kwargs = q[0]
        first = self.queue.toSortedSeq()[0]
        time = timefunc()
        if first.time > time:
            delay = true
        else:
            delay = false
            discard self.queue.pop()
        release(self.L)
        if delay:
            if not blocking:
                return some(first.time - time)
            delayfunc(first.time - time)
        else:
            first.action(first.args)
            delayfunc(0)   # Let other threads run
        
        # return none(int)
