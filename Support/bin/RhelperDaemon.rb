#!/usr/bin/env ruby -Eutf-8

###################################
#
# R daemon for as Helper
#
# written by Hans-Jörg Bibiko - bibiko@eva.mpg.de
###################################

require 'pty'
require 'fileutils'
require 'shellwords'

$pipe_in = "/tmp/textmate_Rhelper_in"
$pipe_out = "/tmp/textmate_Rhelper_out"
$pipe_status = "/tmp/textmate_Rhelper_status"
$pipe_console = "/tmp/textmate_Rhelper_console"

# Locate the R binary. An explicit TM_REXEC wins; otherwise search PATH plus
# the usual install locations, since the helper's shell PATH often misses
# /usr/local/bin, /opt/homebrew/bin, etc. and bare "R" then fails with
# "command not found", leaving callers to time out with "No RESULT".
R_GUESS_PATHS = [
	'/usr/local/bin/R',
	'/opt/homebrew/bin/R',
	'/opt/R/bin/R',
	'/Library/Frameworks/R.framework/Resources/bin/R'
].freeze

def find_r_binary
	if ENV['TM_REXEC'] && !ENV['TM_REXEC'].empty?
		r = ENV['TM_REXEC'].include?('/') ? ENV['TM_REXEC'] : %x{command -v #{ENV['TM_REXEC'].shellescape}}.strip
		return r if r && !r.empty? && File.executable?(r)
		%x{osascript -e 'tell app "TextMate" to display dialog "TM_REXEC “#{ENV['TM_REXEC']}” not found. Searching for R instead." buttons "OK" default button "OK"'}
	end
	found = %x{command -v R}.strip
	return found unless found.empty?
	R_GUESS_PATHS.find { |p| File.executable?(p) }
end

R_BIN = find_r_binary
if R_BIN.nil?
	%x{osascript -e 'tell app "TextMate" to display dialog "Could not find the R binary. Set TM_REXEC to its full path (e.g. /usr/local/bin/R) in TextMate preferences." buttons "OK" default button "OK"'}
	exit 206
end

cmd = "#{R_BIN.shellescape} -q --vanilla --encoding=UTF-8 --TMRHelperDaemon 2&> #{$pipe_console.shellescape}"

FileUtils.rm_f($pipe_out)
FileUtils.rm_f($pipe_status)
FileUtils.rm_f($pipe_console)

File.write($pipe_status, 'TM_RHelper')
File.write($pipe_out, 'TM_RHelper')

PTY.spawn(cmd) { |r,w,pid|

	r.sync = FALSE

	# write r to the nirvana
	Thread.new {
		r.read
	}

	# Thread to destroy daemon after quitting TextMate
	Thread.new do
		# Check if TextMate is still running; if not terminate Help Daemon
		while TRUE
			sleep 10
			break if %x{ps -ax | grep "[0-9] /.*app.*/TextMate" | cut -d ' ' -f2}.empty?
		end
		w.puts("q('no')")
		FileUtils.rm_f($pipe_in)
		FileUtils.rm_f($pipe_out)
		FileUtils.rm_f($pipe_status)
		FileUtils.rm_f($pipe_console)
		FileUtils.rm_f("/tmp/textmate_Rhelper_head.html")
		FileUtils.rm_f("/tmp/textmate_Rhelper_data.html")
		FileUtils.rm_f("/tmp/textmate_Rhelper_search.html")
	end

	$fin = File.open($pipe_in, "r+")
	
	w.puts "source('RhelperScript.R')"

	File.write($pipe_status, 'STARTED')

	while TRUE
		task = $fin.gets.chomp
		%x{echo -en "BUSY" > '#{$pipe_status}'}
		if task[0,1] == "@"
			w.puts "sink('/tmp/textmate_Rhelper_out');TM_Rdaemon#{task[1..-1]};sink(file=NULL);cat('READY',file='#{$pipe_status}',sep='')"
		else
			w.puts "sink('/tmp/textmate_Rhelper_out');#{task};sink(file=NULL);cat('READY',file='#{$pipe_status}',sep='')"
		end
    w.puts "cat('READY',file='#{$pipe_status}',sep='');while(sink.number()>0){sink(file=NULL)}"
	end
}
