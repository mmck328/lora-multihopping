require 'rubygems'
require 'serialport'
require 'fileutils'
require_relative './logger'

$serial_port = '/dev/ttyUSB0'
#$serial_port = '/dev/ttyAMA0'
$serial_baudrate = 115200
serial_databit = 8
$serial_stopbit = 1
$serial_paritycheck = 0
$serial_delimiter = "\r\n"

$sp = SerialPort.new($serial_port, $serial_baudrate, $serial_databit, $serial_stopbit, $serial_paritycheck)
$sp.read_timeout=5000 

$logger = Logger.new('relay_log')

received = nil 
return_rssi = true

def send_rssi(matched, panid, srcid)
  $logger.log("Return RSSI to origin:#{srcid}")
  $sp.write(panid + srcid + "ACK:-" + matched[:rssi] + "dBm" + $serial_delimiter)  
  response = $sp.gets($serial_selimiter)
  if response 
    $logger.log(response)
    sleep(0.2) 
  end
end

while true
  incoming = $sp.gets($serial_delimiter)
  if incoming
    $logger.log(incoming)
    if received
      panid = received[:panid]
      srcid = received[:srcid]
      dstid = received[:dstid]

      matched = incoming.match(/RSSI\(\-(?<rssi>\d+)dBm\)\:Receive Data\((?<payload>.*)\)\r\n/)

      if matched && srcid.hex > dstid.hex
        nextid = format("%04X", [dstid.hex - 1, 0].max) 
        rssi = matched[:rssi]
        payload = matched[:payload]
        $logger.log("received payload: " + payload)

        if payload.include?("RSSI OFF")
          return_rssi = false
        elsif payload.include?("RSSI ON")
	  return_rssi = true
	else
          orgid = payload[0..3]
          if srcid == orgid && return_rssi # for measurement
            send_rssi(matched, panid, srcid)
          end

          $logger.log("Relay payload to next node:#{nextid}")
          $sp.write(panid + nextid + payload + $serial_delimiter) 
        end
      end 
    end 
    received = incoming.match(/--> receive data info\[panid = (?<panid>[0-9A-F]{4}), srcid = (?<srcid>[0-9A-F]{4}), dstid = (?<dstid>[0-9A-F]{4}), length = (?<length>[0-9A-F]{2})\]/)
  end
end

file.close
sp.close
