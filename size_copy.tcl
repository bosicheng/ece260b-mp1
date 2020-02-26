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
    if { [regexp {[a-z][a-z][0-9][0-9]m[0-9][0-9]} $libcellName] } { 
        set newlibcellName [string replace $libcellName 4 4 f]
        return $newlibcellName
    }
    
    if { [regexp {[a-z][a-z][0-9][0-9]s[0-9][0-9]} $libcellName] } { 
        set newlibcellName [string replace $libcellName 4 4 m]
        return $newlibcellName
    }
    
    if { [regexp {[a-z][a-z][0-9][0-9]f[0-9][0-9]} $libcellName] } { 
        set newlibcellName $libcellName
        return "skip"
    }

}

proc Report {} {
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
}

# Calculate sensitivity and place the corresponding element into the M dictionary
# c_i is cellName
proc ComputeSensitivity { c_i mode } {
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
        set newlibcellName [getNextVtUpModified $libcellName]
    }

    size_cell $c_i $newlibcellName

    set nextSlack [PtCellSlack $c_i]
    set nextDelay [PtCellDelay $c_i]
    set nextLeak [PtCellLeak $c_i]
    # puts "==================="
    # puts $nextDelay
    # puts $originalDelay
    # puts $nextLeak
    # puts $originalLeak
    # puts $nextSlack
    # puts $originalSlack
    # puts [expr  ($originalLeak - $nextLeak) * ($originalSlack - $nextSlack) / ($nextDelay - $originalDelay)  ]

    # set sensitivity [expr { ($nextLeak - $originalLeak) * ($nextSlack - $originalSlack) / ($nextDelay - $originalDelay) * ( [PtTimingPaths $c_i] ) } ]
    set sensitivity [expr  ($originalLeak - $nextLeak) * $originalSlack / ($nextDelay - $originalDelay)  ]
    
	# restore the original cell
    size_cell $c_i $libcellName

    return $sensitivity
}

# Sort M in descending order according to sensitivity
proc GetMostSensitiveCell { M } {
	set HighestSensitivitySeen 0
	set IndexOfCell 0

	dict for {id cell} $M {
		# puts "========================================================="
		puts "id: $id"
		dict with cell {
			# puts "target: $target, change: $change, sensitivity: $sensitivity"
			if {$sensitivity > $HighestSensitivitySeen} {
				set HighestSensitivitySeen $sensitivity
				set IndexOfCell $id
			}
		}
	}
	# puts "========================================================="

	return $IndexOfCell
}

# Calculate sensitivity for each cell in netlist
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
        set tempSensitivity [ComputeSensitivity $cellName "downsize"]
        dict set M $index target $cellName
        dict set M $index change "downsize"
        dict set M $index sensitivity $tempSensitivity
    }

    if { [getNextVtUpModified $libcellName] != "skip" } {
        set tempSensitivity [ComputeSensitivity $cellName "upscale"]
        if { [dict exists $M $index] == 0 || [dict get $M $index sensitivity] < $tempSensitivity } {
            dict set M $index target $cellName
			dict set M $index change "upscale"
			dict set M $index sensitivity $tempSensitivity
        }
    }

	incr index
}

puts "========================================================="
puts "start loop..."
set LoopLimit 100
set LoopCount 1
while { [dict size $M] && LoopCount < LoopLimit} {
	incr LoopCount
	puts "Current loop count: $LoopCount"
	
	set IndexOfCell [GetMostSensitiveCell $M]
	set target [dict get $M $IndexOfCell target]
	set change [dict get $M $IndexOfCell change]
	set sensitivity [dict get $M $IndexOfCell sensitivity]

	puts "Target cell: $target, change: $change, sensitivity: $sensitivity"
	puts "========================================================="

	set libcell [get_lib_cells -of_objects $target]
    set libcellName [get_attri $libcell base_name]

	set newlibcellName "null"
    if { $chaneg == "downsize" } {
        set newlibcellName [getNextSizeDown $libcellName]
    }
    if { $change == "upscale" } {
        set newlibcellName [getNextVtUpModified $libcellName]
    }

	size_cell $target $newlibcellName

	set newWNS [ PtWorstSlack clk ]
	if { $newWNS < 0.0 } {
		# restore the original cell
		puts "WNS goes negative. Withdraw this modification."
		size_cell $target $libcellName
		continue
	}

	puts "WNS is OK."
	puts "Cell ${target} is swapped to $newlibcellName"

	# Remove this cell from M
	set M [dict remove $M IndexOfCell]
	# Add modification plans to M
	set tempSensitivity 0
    if { [getNextSizeDown $newlibcellName] != "skip" } {
        set tempSensitivity [ComputeSensitivity $target "downsize"]
        dict set M $index target $target
        dict set M $index change "downsize"
        dict set M $index sensitivity $tempSensitivity
    }
    if { [getNextVtUpModified $newlibcellName] != "skip" } {
        set tempSensitivity [ComputeSensitivity $cellName "upscale"]
        if { [dict exists $M $index] == 0 || [dict get $M $index sensitivity] < $tempSensitivity } {
            dict set M $index target $target
			dict set M $index change "upscale"
			dict set M $index sensitivity $tempSensitivity
        }
    }

	incr index

	if {$LoopCount % 10 == 0} {
		[Report]
	}
}


[Report]
close $outFp    


