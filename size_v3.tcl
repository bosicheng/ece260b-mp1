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


# Self modified Next Vt Up to return "skip" if invalid
proc getNextVtUpModified { libcellName } {
    # if { [regexp {[a-z][a-z][0-9][0-9]m[0-9][0-9]} $libcellName] } { 
    #     set newlibcellName [string replace $libcellName 4 4 f]
    #     return $newlibcellName
    # }
    
    # if { [regexp {[a-z][a-z][0-9][0-9]s[0-9][0-9]} $libcellName] } { 
    #     set newlibcellName [string replace $libcellName 4 4 m]
    #     return $newlibcellName
    # }
    
    # if { [regexp {[a-z][a-z][0-9][0-9]f[0-9][0-9]} $libcellName] } { 
    #     set newlibcellName $libcellName
    #     return "skip"
    # }
    if { [regexp {[a-z][a-z][0-9][0-9]f[0-9][0-9]} $libcellName] } { 
	        set newlibcellName [string replace $libcellName 4 4 m]
		return $newlibcellName
	}
	
	if { [regexp {[a-z][a-z][0-9][0-9]m[0-9][0-9]} $libcellName] } { 
        	set newlibcellName [string replace $libcellName 4 4 s]
		return $newlibcellName
	}
	
	if { [regexp {[a-z][a-z][0-9][0-9]s[0-9][0-9]} $libcellName] } { 
		return "skip"
	}

}


# Calculate sensitivity and place the corresponding element into the M dictionary
proc ComputeSensitivity { c_i mode } {
    set libcell [get_lib_cells -of_objects $c_i]
    set libcellName [get_attri $libcell base_name]
    set originalSlack [PtCellSlack $c_i]
    set originalDelay [PtCellDelay $c_i]
    set originalLeak [PtCellLeak $c_i]

    set newlibcellName "skip"
    if { $mode == "downsize" } {
        set newlibcellName [getNextSizeDown $libcellName]
    }

    if { $mode == "upscale" } {
        set newlibcellName [getNextVtUpModified $libcellName]
    }

    if { $newlibcellName == "skip"} {
    	return 0
    }

    size_cell $c_i $newlibcellName
    # set nextSlack [PtCellSlack $c_i]
    set nextDelay [PtCellDelay $c_i]
    set nextLeak [PtCellLeak $c_i]

    set path [PtCellFanout $c_i]
    #puts "==================="
    #puts $nextDelay
    #puts $originalDelay
    #puts $nextLeak
    #puts $originalLeak
    #puts $nextSlack
    #puts $originalSlack
    #puts [expr  ($originalLeak - $nextLeak) * ($originalSlack - $nextSlack) / ($nextDelay - $originalDelay)  ]

    # set sensitivity [expr { ($nextLeak - $originalLeak) * ($nextSlack - $originalSlack) / ($nextDelay - $originalDelay) * ( [PtTimingPaths $c_i] ) } ]
    # set sensitivity [expr  ($originalLeak - $nextLeak) * ($originalSlack - $nextSlack) / ($nextDelay - $originalDelay)  ]
    # set sensitivity [expr  -($nextLeak - $originalLeak) * $originalSlack / ($nextDelay - $originalDelay)]
    set sensitivity [expr  -($nextLeak - $originalLeak) * $originalSlack / $path]


    size_cell $c_i $libcellName

    return $sensitivity
}

set index 1
set total [sizeof $cellList]

foreach_in_collection cell $cellList {
    set cellName [get_attri $cell base_name]
    set libcell [get_lib_cells -of_objects $cellName]
    set libcellName [get_attri $libcell base_name]
    if {$libcellName == "ms00f80" || ![regexp {[a-z][a-z][0-9][0-9][smf][0-9][0-9]} $libcellName]} {
        continue
    }

    if { ![regexp {[a-z][a-z][0-9][0-9][smf]01} $libcellName] } {
    	set tempSensitivity [ComputeSensitivity $cellName "downsize"]
	    dict set M $index target $cellName
	    dict set M $index change "downsize"
	    dict set M $index sensitivity $tempSensitivity
    }

	
    if { ![regexp {[a-z][a-z][0-9][0-9]s[0-9][0-9]} $libcellName]} {
        set tempSensitivity [ComputeSensitivity $cellName "upscale"]
        if { [dict exists $M $index] && [dict get $M $index sensitivity] > $tempSensitivity } {
            continue
        }
        dict set M $index target $cellName
        dict set M $index change "upscale"
        dict set M $index sensitivity $tempSensitivity
    }

    incr index
    puts "=======================Now $index of $total Complete========================="
}

# puts $M

set counter 0
while { [dict size $M] } {
    incr counter
    set maxSen 0
    set maxInd 0
    foreach key [dict keys $M] {
    if { $maxSen < [dict get $M $key sensitivity]} {
        set maxSen [dict get $M $key sensitivity]
        set maxInd $key
        }
    }
    
    if { $maxInd == 0 || counter == 1000} {
    	break
    }

    puts "===========================Test========================="
    puts "================$counter |||| $maxInd ||||  [dict size $M] ============"

    set targetCell [dict get $M $maxInd target]
    # puts $targetCell
    set targetlibcell [get_lib_cells -of_objects $targetCell]
    set targetlibcellName [get_attri $targetlibcell base_name]

    set targetChange [dict get $M $maxInd change]

    if { $targetChange == "downsize" } {
        set newLibCellName [getNextSizeDown $targetlibcellName]
        size_cell $targetCell $newLibCellName
    } else {
        set newLibCellName [getNextVtUpModified $targetlibcellName]
        size_cell $targetCell $newLibCellName
    }

    set M [dict remove $M $maxInd]
    set nextWNS [PtWorstSlack clk]
    set CapNoVio "Sum/Max/Number of max capacitance violations: 0 / 0 / 0"
    set TranNoVio "Sum/Max/Number of max transition violations: 0 / 0 / 0"
    if { $nextWNS < 0 || [PtGetCapVio] != $CapNoVio || [PtGetTranVio] != $TranNoVio } {
        size_cell $targetCell $targetlibcellName
    } else {
    	puts "=======================Right Begin======================="
        if { $targetChange == "downsize"} {
            incr SizeswapCnt
        } else {
            incr VtswapCnt
        }

        if { ![regexp {[a-z][a-z][0-9][0-9][smf]01} $targetlibcellName] } {
        	set tempSensitivity [ComputeSensitivity $targetCell "downsize"]
            dict set M $index target $targetCell
            dict set M $index change "downsize"
            dict set M $index sensitivity $tempSensitivity
        }

        if { ![regexp {[a-z][a-z][0-9][0-9]s[0-9][0-9]} $targetlibcellName] } {
        	set tempSensitivity [ComputeSensitivity $targetCell "upscale"]
            if { [dict exists $M $index] && [dict get $M $index sensitivity] > $tempSensitivity } {
                continue
            }
            dict set M $index target $targetCell
            dict set M $index change "upscale"
            dict set M $index sensitivity $tempSensitivity
        }
        incr index
    }
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

#puts "==================="
#puts $M

