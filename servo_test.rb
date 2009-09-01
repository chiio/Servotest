require "rubygems"
require "serialport"

running = true

begin
	port_file = "/dev/ttyUSB2"
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

data = Array.new()
puts "Torque [Nm]:"
torque = gets

time.each_with_index do |period,k|

data << {:time => Array.new(),
		:theoric_angle => Array.new(),
		:measured_angle => Array.new()}
		
sp.puts "#{period}t"

sleep 0.1
sp.puts "s"
sleep 0.1

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
running = true
end

graph = true

maxDerivFunction = ["maxDeriv <- function (time,angle) {\n",
					"dc = c(1:length(time)-2)\n",
					"for (i in 1:length(time)-2) {\n",
					"dc[i] = (angle[i+2]-angle[i])/(time[i+2]-time[i])}\n",
					"max(dc) }" ]

File.open("servotest.r", "w") do |f| 
	f.puts "rm(list=ls(all=TRUE));"
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
	f.puts "x <- matrix(nrow = 1, ncol = 2)"
	f.puts "x[1,1] = max(omegaMax)"
	f.puts "x[1,2] = #{torque}"	
	f.puts "write(x, file = \"results.dat\", append = TRUE, sep = \" \")"
end

exec "R --vanilla -q < servotest.r"

