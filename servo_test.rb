require "rubygems"
require "serialport"

running = true
repeat  = "n"
resp    = "y"

STDOUT.sync = true
system "clear"

begin
	port_file = "/dev/ttyUSB0"
	sp = SerialPort.new(port_file, 57600, 8, 1, SerialPort::NONE)
rescue
	warn "ERROR: No device connected."
	exit(0)
end	

iang = 20
fang = 100
time = [5000,3500,2500,1750,1000,500,250,100,50,10]
omegaMean = Array.new()

time.each_with_index {|t,k| omegaMean[k] = (fang-iang)/t.to_f}

sp.puts "r"
sp.puts "#{iang}i"
sp.puts "#{fang}f"

print "What's the name of servomotor? : "
motorname = gets

resultsfn = [motorname.chomp,"-results.dat"].join
logfile   = [motorname.chomp,"-results.log"].join

if File.exist? resultsfn
	last = File.open(resultsfn) { |f| f.extend(Enumerable).inject { |_,ln| ln }}
	order = last.split[0].to_i
else
	order = 0
end
		
while resp == "y"

order +=1
data = Array.new()
if repeat != "y"
	print "Torque [Nm] : "
	torque = gets
end	

time.each_with_index do |period,k|

data << {:time => Array.new(),
		:theoric_angle => Array.new(),
		:measured_angle => Array.new()}
		
sp.puts "#{period}t"

sleep 0.1
sp.puts "s"
sleep 0.1

print "Test #{k}..."
while running
	sleep 0.05
	line = sp.gets
	if line != nil
		line = line.split
		data[k][:time] << line[0].to_f
		data[k][:theoric_angle] << line[1].to_f
		data[k][:measured_angle] << line[2].to_f/10.0
	end	
	running = false if line == nil	
end

data[k].each {|d| d.delete_at(0)}

sp.puts "r"
#puts "Press ENTER to continue"
#gets
sleep 1
puts " complete!"
running = true
end

graph = true

maxDerivFunction = ["maxDeriv <- function (time,angle) {\n",
					"dc = c(1:length(time)-2)\n",
					"for (i in 1:length(time)-2) {\n",
					"dc[i] = (angle[i+2]-angle[i])/(time[i+2]-time[i])}\n",
					"max(dc) }" ]

if !File.exist? resultsfn
	File.open(resultsfn,"w") do |f|
		f.puts "order omegaMax torque"
	end
end

filename = [motorname.chomp,"-",torque.to_s.chomp,".r"].join
File.open(filename, "a") do |f| 
	f.puts "rm(list=ls(all=TRUE));"
	f.puts "pdf(\"#{motorname.chomp}-#{torque.chomp}.pdf\", paper=\"a4r\")"
	f.puts "omegaMean = c(#{omegaMean.join(",")})"
	f.puts "omegaMax = c(1:#{omegaMean.length})"
	f.puts maxDerivFunction
	omegaMean.each_with_index do |w,i|
		f.puts "time <- c(#{data[i][:time].join(",")})"
		f.puts "theoric_angle <- c(#{data[i][:theoric_angle].join(",")})"
		f.puts "measured_angle <- c(#{data[i][:measured_angle].join(",")})"
		if graph
			f.puts "split.screen(c(2,1), erase = TRUE)"
			f.puts "screen(1)"	
			f.puts "plot(time,measured_angle, main=\"#{iang} -> #{fang} in #{time[i]} ms\")"
			f.puts "screen(2)"
			f.puts "plot(theoric_angle,measured_angle)"
			f.puts "close.screen(all = TRUE)"
		end
		f.puts "omegaMax[#{i+1}] = maxDeriv(time,measured_angle)"
	end
	f.puts "plot(omegaMean,omegaMax,\"b\")"
	f.puts "close.screen(all = TRUE)"
	f.puts "x <- matrix(nrow = 1, ncol = 3)"
	f.puts "x[1,1] = #{order}"
	f.puts "x[1,2] = max(omegaMax)"
	f.puts "x[1,3] = #{torque}"
	f.puts "write(x, file = \"#{resultsfn}\", append = TRUE, sep = \" \")"
end

print "Do you want to repeat this test? <y/n> : "
repeat = gets.chomp

if repeat != "y"
	command = ["R --vanilla -q < ", filename].join
	system command
	print "Do you want to do another test? <y/n> : "
	resp = gets.chomp
else
	resp = "y"
end
end

filename = [motorname.chomp,"-results.r"].join
File.open(filename, "w") do |f|
	f.puts "rm(list=ls(all=TRUE));"
	f.puts "pdf(\"#{motorname.chomp}-results.pdf\", paper=\"a4r\")"	
	f.puts "df <- read.table(\"#{resultsfn}\", header=TRUE)"
	f.puts "attach(df)"
	f.puts "df.lm <- lm(torque ~ omegaMax, data = df)"
	f.puts "coef <- coefficients(df.lm)"
	f.puts "plot(omegaMax,torque,main=\"Characteristic curve of the servomotor #{motorname.chomp}\",xlab=\"omega [°/ms]\",ylab=\"torque [Nm]\")"
	f.puts "abline(df.lm,lwd=3)"	
	f.puts "df.lm <- lm(torque ~ omegaMax * order, data = df)"
	f.puts "write(\"Coefficient:\", file = \"#{logfile}\", append = FALSE)"
	f.puts "write(\"q:\tm:\", file = \"#{logfile}\", append = TRUE)"
	f.puts "write(coef, file = \"#{logfile}\", append = TRUE, sep = \"\t\")"
	f.puts "write(\"---\", file = \"#{logfile}\", append = TRUE)"
	f.puts "write(\"Anova:\", file = \"#{logfile}\", append = TRUE)"
	f.puts "write.table(anova(df.lm),file = \"#{logfile}\", append = TRUE, sep = \"\t\")"
	f.puts "detach(df)"
end

command = ["R --vanilla -q < ", filename].join
system command

puts "Finish."
