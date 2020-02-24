set design [get_attri [current_design] full_name]
set outFp [open ${design}_sizing.rpt w]

set initialWNS  [ PtWorstSlack clk ]
set initialLeak [ PtLeakPower ]
set capVio [ PtGetCapVio ]
set tranVio [ PtGetTranVio ]
puts "Initial slack:\t${initialWNS} ps"
puts "Initial leakage:\t${initialLeak} W"
puts "Final $capVio"
puts "Final $tranVio"
puts "======================================" 
puts $outFp "Initial slack:\t${initialWNS} ps"
puts $outFp "Initial leakage:\t${initialLeak} W"
puts $outFp "Final $capVio"
puts $outFp "Final $tranVio"
puts $outFp "======================================" 

set cellList [sort_collection [get_cells *] base_name]
set VtswapCnt 0
set SizeswapCnt 0

set M [list]

proc ComputeSensitivity {c_i, downsize} {

}

foreach_in_collection cell $cellList {
	set cellName [get_attri $cell base_name]
    set libcell [get_lib_cells -of_objects $cellName]
    set libcellName [get_attri $libcell base_name]
    if {$libcellName == "ms00f80"} {
        continue
    }

    # if is downsizeable
    if { [regexp {[a-z][a-z][0-9][0-9][smf]08} $libcellName] } { 
    	set m_target libcellName
    	set m_change [set newlibcellName [string replace $libcellName 5 6 "04"]]
    	set m_sensitivity ComputeSensitivity(libcellName, m_change)
    	set m {m_target m_change m_sensitivity}
    	lappend M m
    }

    # if is not a HVT
    if { [regexp {[a-z][a-z][0-9][0-9]f[0-9][0-9]} $libcellName] } {
    	set m_target libcellName
    	set m_change [set newlibcellName [string replace $libcellName 4 4 m]]
    	set m_sensitivity ComputeSensitivity(libcellName, m_change)
    	set m {m_target m_change m_sensitivity}
    	lappend M m
    }
}

while { [llength M] != 0 } {

}

set finalWNS  [ PtWorstSlack clk ]
set finalLeak [ PtLeakPower ]
set capVio [ PtGetCapVio ]
set tranVio [ PtGetTranVio ]
set improvment  [format "%.3f" [expr ( $initialLeak - $finalLeak ) / $initialLeak * 100.0]]
puts $outFp "======================================" 
puts $outFp "Final slack:\t${finalWNS} ps"
puts $outFp "Final leakage:\t${finalLeak} W"
puts $outFp "Final $capVio"
puts $outFp "Final $tranVio"
puts $outFp "#Vt cell swaps:\t${VtswapCnt}"
puts $outFp "#Cell size swaps:\t${SizeswapCnt}"
puts $outFp "Leakage improvment\t${improvment} %"

close $outFp    


