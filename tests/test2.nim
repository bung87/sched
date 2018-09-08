

import sched
import times
export sched
import options
import locks
# nim c --threads:on -r src/sched.nim 
# when isMainModule:

type
    MineData = object
        a: string

var s2 = initScheduler[MineData]()
proc print_time(a = "default") =
    echo "From print_time:", a, " ", epochTime()

proc print_time2(a: MineData) =
    echo "From print_time:", a.a, " ", epochTime()

proc print_some_times(){.thread.} =
    echo epochTime()
    var s = initScheduler[string]()
    discard s.enter(10, 1, print_time, "a")
    discard s.enter(5, 2, print_time, "b")

    var r = s.run()
    try:
        echo r.get()
        assert(false)         # This will not be reached
    except UnpackError: # Because an exception is raised
        discard
    echo epochTime()

proc print_some_times2(){.thread.} =
    echo epochTime()
    var s = initScheduler[string]()
    discard s.enter(10, 1, print_time, "c")
    discard s.enter(5, 2, print_time, "d")

    var r = s.run()
    try:
        echo r.get()
        assert(false)         # This will not be reached
    except UnpackError: # Because an exception is raised
        discard
    echo epochTime()

var
    thr: array[2, Thread[void]]

createThread(thr[0], print_some_times)
createThread(thr[1], print_some_times2)
joinThreads(thr)
echo epochTime()
