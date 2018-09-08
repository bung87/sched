 
import sched
import times
export sched
 # nim c --threads:on -r src/sched.nim 
# when isMainModule:

type 
    MineData = object
        a:string
var s = initScheduler[string]()
var s2 = initScheduler[MineData]()
proc print_time(a="default") =
    echo "From print_time:",a," ", epochTime()

proc print_time2(a:MineData) =
    echo "From print_time:",a.a," ", epochTime()
    
proc print_some_times() =
    echo epochTime()
    discard s.enter(10, 1, print_time,"a")
    discard s.enter(5, 2, print_time,"b")
    
    var r = s.run()
    # try:
    #     echo r.get()
    #     assert(false)  # This will not be reached
    # except UnpackError:  # Because an exception is raised
    #     discard
    echo epochTime()

print_some_times()

discard s2.enter(5, 2, print_time2,MineData(a:"minedata"))
let r= s2.run()
echo epochTime()