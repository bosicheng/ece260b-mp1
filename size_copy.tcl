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

# Calculate sensitivity and place the corresponding element into the M dictionary
proc ComputeSensitivity { c_i mode } {
	puts $c_i
	puts $mode

	# set cellName [get_attri $c_i base_name]
    set libcell [get_lib_cells -of_objects $c_i]
    set libcellName [get_attri $libcell base_name]
    set originalSlack [PtCellSlack $c_i]
    set originalDelay [PtCellDelay $c_i]
    set originalLeak [PtCellLeak $c_i]

    set newlibcellName "null"
    if { $mode == "downsize" } {
    	set newlibcellName [getNextSizeDown $libcellName]
    }

    if { $mode == "upscale" } {
    	set newlibcellName [getNextVtDown $libcellName]
    }

    size_cell $c_i $newlibcellName
	set nextSlack [PtCellSlack $c_i]
	set nextDelay [PtCellDelay $c_i]
	set nextLeak [PtCellLeak $c_i]

	# puts "================================="
	# puts [PtTimingPaths $c_i]
	# puts [PtCellFanout $c_i]
	# puts "================================="

	# set sensitivity [expr { ($nextLeak - $originalLeak) * ($nextSlack - $originalSlack) / ($nextDelay - $originalDelay) * ( [PtTimingPaths $c_i] ) } ]
	set sensitivity [expr { ($nextLeak - $originalLeak) * ($nextSlack - $originalSlack) / ($nextDelay - $originalDelay) } ]
	
	size_cell $c_i $libcellName

	return sensitivity
}

set index 0

foreach_in_collection cell $cellList {
	set cellName [get_attri $cell base_name]
    set libcell [get_lib_cells -of_objects $cellName]
    set libcellName [get_attri $libcell base_name]
    if {$libcellName == "ms00f80"} {
        continue
    }

    set tempSensitivity 0
    if { [getNextSizeDown $libcellName] != "skip" } {
    	set $tempSensitivity [ComputeSensitivity $cellName "downsize"]
    	dict set M $index target $cellName
    	dict set M $index change "downsize"
    	dict set M $index sensitivity $tempSensitivity
    }

    if { [getNextVtUp $libcellName] != "skip" } {
    	set $tempSensitivity [ComputeSensitivity $cellName "upscale"]
    	if { [dict exists M index] && [dict get M index sensitivity] > $tempSensitivity } {
    		continue
    	}
   		dict set M $index target $cellName
    	dict set M $index change "upscale"
    	dict set M $index sensitivity $tempSensitivity
    	incr index
    }

    # set sensitivity [ComputeSensitivity $cellName $downsize $upscale]
    # puts $sensitivity
}

# while { [dict size $M] } {

# }

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


