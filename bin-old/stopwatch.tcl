#!/depot/path/wish -f
######################################################################
# Name: Stopwatch
# Author: Don Libes <libes@nist.gov>
# Date first released: 9/26/96
# Description: Stopwatch is a tool for hand timing, such as timing how
#   long a talk or part of a talk takes.  See the home page for more
#   details.
#
set version 3.5
set versionDate 2004/6/23
# For the latest version: http://expect.nist.gov/stopwatch
######################################################################

######################################################################
# User-settable features
######################################################################

catch {                       ;# allow it to run in a browser
    tk_setPalette     #dfd5e7 ;# touch of lavender
}

set time(startColor) #009900  ;# medium green
set time(stopColor)  #ff0000  ;# red
set time(msecShow) 1          ;# To disable millisecond timing, set to 0.
                              ;# Not much reason to do this unless you
			      ;# find the millisecond display distracting
			      ;# or you're timing for more than 24 days.
			      ;# If the version of Tcl that you're using
			      ;# doesn't support millisecond timing, then
			      ;# this option will be disabled automatically.

set time(forward) 1           ;# runs backward when 0
set time(stopAtZero) 1        ;# to use in countdown mode

option add *Entry.font {Times 18}

######################################################################
# End of user-settable features
######################################################################

proc stop {} {
    global time

    .startstop config -text start -command start
    .startstop config -foreground       $time(startColor) \
	              -activeforeground $time(startColor)
    .m.r entryconfigure $::menuStartStopIndex \
	              -foreground       $time(startColor) \
	              -activeforeground $time(startColor) \
    		      -label Start \
    		      -command start
    .m.r entryconfigure $::menuMsecIndex     -state normal
    .m.r entryconfigure $::menuForwardIndex  -state normal
    .m.r entryconfigure $::menuBackwardIndex -state normal

    if {![info exists time(tickId)]} return
    after cancel $time(tickId)
    unset time(tickId)
}

proc start {} {
    global time

    if {[catch {timescan time(total)} time(tstart,relative)]} return
    if {[catch {timescan time(lap)} time(lstart,relative)]} return

    .startstop config -text stop -command stop
    .startstop config -foreground       $time(stopColor) \
	              -activeforeground $time(stopColor)
    .m.r entryconfigure $::menuStartStopIndex \
	              -foreground       $time(stopColor) \
	              -activeforeground $time(stopColor) \
    		      -label Stop \
    		      -command stop
    .m.r entryconfigure $::menuMsecIndex     -state disabled
    .m.r entryconfigure $::menuForwardIndex  -state disabled
    .m.r entryconfigure $::menuBackwardIndex -state disabled
    set now [now]

    if {$time(forward)} {
	set time(tstart) [expr {$now - $time(tstart,relative)}]
	set time(lstart) [expr {$now - $time(lstart,relative)}]
    } else {
	set time(tstart) [expr {$now + $time(tstart,relative)}]
	set time(lstart) [expr {$now + $time(lstart,relative)}]
    }	    

    # start the clock ticking
    tick
}

# configure millisecond support according to the setting of time(msecShow)
proc msecConfig {} {
    global time

    # If millisecond time requested, try it out first and if it doesn't
    # work, fall back to single-second timing.
    if {$time(msecShow) && (0 == [catch {clock clicks -milliseconds}])} {
	proc now {} {clock clicks -milliseconds}
    } else {
	proc now {} {clock seconds}
	set time(msecShow) 0
    }

    # By using either msecs or secs as the underlying quantum, we can get
    # accuracy where we want it.
    if {$time(msecShow)} {
	set time(msecsPerTick)     1
	set time(ticksPerSec)   1000
	set time(ticksPerMin)  60000
	set time(ticksPerHr) 3600000
    } else {
	set time(msecsPerTick)  1000
	set time(ticksPerSec)      1
	set time(ticksPerMin)     60
	set time(ticksPerHr)    3600
    }
}
msecConfig

# tick is called every so often to update the clock.
proc tick {} {
    global time

    set now [now]
    set stop 0

    if {$::time(forward)} {
	set ttime [expr {$now - $time(tstart)}]
	set ltime [expr {$now - $time(lstart)}]

	if {$time(stopAtZero)} {
	    # time has passed zero crossing, so adjust both counters
	    # so at least one of them shows perfect zero and the other
	    # is adjusted by the difference.

	    if {(($time(tstart,relative) < 0) && ($ttime >= 0))} {
		incr ltime [expr {-$ttime}]
		set  ttime 0
		set stop 1
	    } elseif {(($time(lstart,relative) < 0) && ($ltime >= 0))} {
		incr ttime [expr {-$ltime}]
		set  ltime 0
		set stop 1
	    }
	}
    } else {
	set ttime [expr {$time(tstart) - $now}]
	set ltime [expr {$time(lstart) - $now}]

	if {$time(stopAtZero)} {
	    # time has passed zero crossing, so adjust both counters
	    # so at least one of them shows perfect zero and the other
	    # is adjusted by the difference.

	    if {(($time(tstart,relative) > 0) && ($ttime <= 0))} {
		incr ltime [expr {-$ttime}]
		set  ttime 0
		set stop 1
	    } elseif {(($time(lstart,relative) > 0) && ($ltime <= 0))} {
		incr ttime [expr {-$ltime}]
		set  ltime 0
		set stop 1
	    }
	}
    }
    set time(total) [timeformat $ttime]
    set time(lap)   [timeformat $ltime]

    if {$stop} {
	stop
	bell
    } else {
	set time(tickId) [after $time(msecsPerTick) tick]
    }
}

# parse displayed time
proc timescan {timevar} {
    upvar $timevar timetext
    global time

    # possible sign
    regexp ^(-)?(.*) $timetext x sign timetext

    # accept user-supplied time with or without msec
    if {4 != [scan $timetext %d:%d:%d.%d hr min sec msec]} {
	set msec 0
	if {3 != [scan $timetext %d:%d:%d hr min sec]} {
	    set timetext "what?"
	    error "conversion error"
	}
    }

    if {!$time(msecShow)} {
	set msec 0
    }

    set ticks [expr {(($hr*60 + $min)*60 + $sec)*$time(ticksPerSec) + $msec}]
    if {$sign == "-"} {
	set ticks [expr {0 - $ticks}]
    }

    return $ticks
}

# format time for display
proc timeformat {ticks} {
    global time

    if {$ticks < 0} {
	set sign "-"
	set ticks [expr {abs($ticks)}]
    } else {
	set sign ""
    }

    set r $sign[format %03d:%02d:%02d \
	       [expr { $ticks                      /$time(ticksPerHr) }] \
	       [expr {($ticks % $time(ticksPerHr) )/$time(ticksPerMin)}] \
	       [expr {($ticks % $time(ticksPerMin))/$time(ticksPerSec)}]]
    if {$time(msecShow)} {
	append r [format ".%03d" [expr {$ticks % 1000}]]
    }

    return $r
}

proc record {type time} {
    .record.t tag remove sel 1.0 end
    .record.t insert 1.0 "$type $time$::recordeol"
    .record.t tag add sel 1.2 1.end
    .record.t see 1.0
    
    # add newlines after every record but the first
    set ::recordeol "\n"
}
set recordeol ""

########################################################################
# Mostly widget layout stuff after this point.
########################################################################

# Allow enough display space for "hhh:mm:ss.mmm"  These don't literally
# add up because less space is taken by punctuation.
option add *Entry.width 12

label .totallabel -text "total:" -anchor e
entry .totaltime  -textvar time(total)
button .totalzero -text "zero" -command {
    set time(total) [timeformat 0]
    .lapzero invoke
    set time(tstart) [now] ;# if clock running, this needs to be updated
}
button .totalrecord -text "record" -command {
    record T $time(total)
}
proc totalzr {} {
    .totalrecord invoke
    .totalzero invoke
}
bind .totalzero <Control-1> {totalzr; break}
bind .totalrecord <Control-1> {totalzr; break}

label .laplabel -text "lap:" -anchor e
entry .laptime -textvar time(lap)
button .lapzero -text "zero" -command {
    set time(lap) [timeformat 0]
    set time(lstart) [now] ;# if clock running, this needs to be updated
}
button .laprecord -text "record" -command {
    record L $time(lap)
}
proc lapzr {} {
    .laprecord invoke
    .lapzero invoke
}
bind .lapzero <Control-1> {lapzr; break}
bind .laprecord <Control-1> {lapzr; break}

button .startstop -text start -command start \
    -foreground       $time(startColor) \
    -activeforeground $time(startColor)

frame     .record
scrollbar .record.sb -command {.record.t yview}
text      .record.t -height 5 -width 10 -yscroll {.record.sb set}
button    .record.clear -text clear -command {.record.t delete 1.0 end}

grid .totallabel .totaltime .totalrecord .totalzero
grid configure .totallabel    -sticky e
grid configure .totaltime     -sticky ns
grid .laplabel .laptime .laprecord .lapzero
grid configure .laplabel      -sticky e
grid configure .laptime       -sticky ns
grid .startstop -columnspan 4 -sticky ew

grid .record       -columnspan 4    -sticky nsew
grid .record.sb    -column 0 -row 0 -sticky ns
grid .record.t     -column 1 -row 0 -sticky nsew
grid .record.clear -column 2 -row 0 -sticky ns

grid columnconfigure . 0       -weight 1
grid rowconfigure    . 3       -weight 1

grid columnconfigure .record 1 -weight 1
grid rowconfigure    .record 0 -weight 1

########################################
# miscellaneous other things of interest to the UI
########################################
proc about {} {
#    tk_messageBox -message "Stopwatch $::version by Don Libes <don@libes.com>"
    set w .about
    if {[winfo exists $w]} {
	wm deiconify $w
	raise $w
	return
    }
    toplevel     $w
    wm title     $w "about stopwatch"
    wm iconname  $w "about stopwatch"
    wm resizable $w 0 0

    button $w.b -text Dismiss -command [list wm withdraw $w]

    label $w.title -text "Stopwatch" -font "Times 16" -borderwidth 10 -fg red
    label $w.version -text "Version $::version, Released $::versionDate"
    label $w.author -text "Written by Don Libes <don@libes.com>"
    label $w.using -text "Using Tcl $::tcl_patchLevel,\
                                Tk $::tk_patchLevel"
    grid $w.title
    grid $w.version
    grid $w.author
    grid $w.using
    grid $w.b -sticky ew
}

proc help {} {
    if {[winfo exists .help]} {
	destroy .help
	return
    }

    toplevel .help
    wm title .help "Stopwatch help"
    wm iconname .help "Stopwatch help"

    scrollbar .help.sb -command {.help.text yview}
    text .help.text -width 80 -height 30 -yscroll {.help.sb set} -wrap word

    button .help.ok -text "OK" -command {destroy .help} -relief raised
    bind .help <Return> {destroy .help;break}
    grid .help.sb -row 0 -column 0 -sticky ns
    grid .help.text -row 0 -column 1 -sticky nsew
    grid .help.ok -row 1 -columnspan 2 -sticky ew  -padx 2 -pady 2

    # let text box only expand
    grid rowconfigure .help 0 -weight 1
    grid columnconfigure .help 1 -weight 1

    .help.text tag configure h1 -foreground #008000

    .help.text insert end "Stopwatch $::version - by Don Libes <don@libes.com>" h1
    .help.text insert end {

Stopwatch does what its name implies - enables hand timing much like a physical stopwatch.  Stopwatch can also countdown like a timer.

Stopwatch runs on UNIX, Windows, and MacOS.  Stopwatch may run as a traditional program or in a browser.

}

    .help.text insert end "Directions" h1
    .help.text insert end {

Press "start" to start timing and "stop" to stop it.  "record" records the current time and selects it so that it can readily be pasted into other programs.  Recorded times are marked with an L for "lap" or T for "total".  When stopped, you can cut/paste/edit the time by hand and set it to any valid time.  "zero" resets the time to zero.

Time moves forward or backward according to the Run menu.  By default, time stops automatically when either the lap or total time reaches zero.  To disable the automatic stop, unselect Run -> Stop At Zero.

}

    .help.text insert end "Shortcuts" h1
    .help.text insert end "

<z> zeros the lap time.  <Z> zeros the total time.
<r> resets the lap time.  <R> resets the total time.
<s> starts/stops the time.
<c> clears the recorded times.

Holding down the control key while pressing the record or zero buttons/keys, records and then zeros the time.

"

    .help.text insert end "Caveats" h1
    .help.text insert end {

Stopwatch requires Tcl/Tk.  Millisecond timing is only available when using Tcl 8.3 or later.

By default, the maximum time is just over 596 hours (about 25 days).  The range may be increased (to about 68 years) by disabling the millisecond timer.  To disable the millisecond timer, select Run => Milliseconds (or edit the source to change it permanently.)

By default, the "Stop At Zero" action is a bell.  To change this, edit the source and redefine the "bell" procedure as desired.}
}

######################################################################
# set up menu bar
######################################################################

menu .m -tearoff 0
.m add cascade -menu .m.f    -label "File"  -underline 0
.m add cascade -menu .m.e    -label "Edit"  -underline 0
.m add cascade -menu .m.r    -label "Run"   -underline 0
.m add cascade -menu .m.help -label "Help"  -underline 0

menu .m.f
menu .m.e
menu .m.r
menu .m.help

.m.f    add command -label "Exit"	-command exit

.m.e    add command -label "Cut" 	-command {event generate [selection own] <<Cut>>}
.m.e    add command -label "Copy"       -command {event generate [selection own] <<Copy>>}
.m.e    add command -label "Paste"      -command {event generate [selection own] <<Paste>>}
.m.e    add command -label "Clear"      -command {selection clear}
.m.e    add command -label "Select All" -command {selectAll}

proc selectAll {} {
    set w [focus]
    if {$w == "."} {
	# if no focus, use recording area
	set w .record.t
    }

    switch [winfo class $w] {
	"Text" {
	    $w tag remove sel 0.0 end
	    $w tag add sel 1.0 end
	} "Entry" {
	    $w selection range 0 end
	}
    }
}

# Note that changes to this menu may impact the indexes below which
# are manually calculated.
.m.r    add command -label "Start"      -command start
.m.r    add checkbutton -label "Stop At Zero" -variable time(stopAtZero)
.m.r    add checkbutton -label "Milliseconds" -variable time(msecShow) -command msecConfig
.m.r    add radio   -label "Forward"    -variable time(forward) -value 1
.m.r    add radio   -label "Backward"   -variable time(forward) -value 0
set menuStartStopIndex 1
set menuMsecIndex      3
set menuForwardIndex   4
set menuBackwardIndex  5
.m.r entryconfigure $::menuStartStopIndex \
	              -foreground       $time(startColor) \
	              -activeforeground $time(startColor)

.m.help add command -label "About"      -command about
.m.help add command -label "Help"       -command help
. config -m .m

.totalzero invoke

bind all <s> {.startstop    invoke}
bind all <c> {.record.clear invoke}

bind all <r> {.laprecord    invoke} ; bind all <Control-r> {lapzr}
bind all <R> {.totalrecord  invoke} ; bind all <Control-R> {totalzr}
bind all <z> {.lapzero      invoke} ; bind all <Control-z> {lapzr}
bind all <Z> {.totalzero    invoke} ; bind all <Control-Z> {totalzr}
