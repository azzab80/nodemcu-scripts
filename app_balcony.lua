--
-- Plant watering mechanism on the balcony
--
-- Controls the pump and reads the water level sensor
--
local module = {}

local PIN_LEVEL = 1 -- GPIO5
local PIN_PUMP  = 2 -- GPIO4

-- handle the low water level sensor
--
-- Sends water level info to the MQTT broker
--
-- @param {bool} level 1 for high water, 0 for low
--
local function on_level_change(level)
  print("Low water sensor: " .. level)
  G.mqtt.publish("sensor/waterlevel", level, 1, 1)

  -- low water - disable the pump
  if(level == 0) then
    module.stop_pump()
  end

  -- listen to inverted state now
  gpio.trig(PIN_LEVEL, level == gpio.HIGH  and "down" or "up")
end

-- check the current water level
--
-- @returns {int} 1 for high water, 0 for low
--
local function get_current_level()
  return gpio.read(PIN_LEVEL)
end

-- start the pump
--
-- checks the current water level and does nothing if it's too low
--
function module.start_pump()
  print "pump requested"
  if(get_current_level() == 1) then
    print "PUMP STARTED"
    gpio.write(PIN_PUMP, gpio.HIGH)
    G.mqtt.publish("sensor/pump", "1", 1)
    -- safety: shut down after 45s
    tmr.create():alarm(45 * 1000, tmr.ALARM_SINGLE, module.stop_pump)
  end
end

-- stop the pump
function module.stop_pump()
  print "PUMP STOPPED"
  gpio.write(PIN_PUMP, gpio.LOW)
  G.mqtt.publish("sensor/pump", "0", 1)
end

-- configure everything
local function setup()
  -- publish current level after startup
  G.mqtt.waitThen(function()
    local level = get_current_level()
    G.mqtt.publish("sensor/waterlevel", level, 1, 1)
  end)

  -- start wifi and mqtt
  G.wifi.waitThen(G.mqtt.start)

  -- water level monitoring by interrupt
  gpio.mode(PIN_LEVEL, gpio.INT, gpio.PULLUP)
  gpio.trig(PIN_LEVEL, "down", on_level_change)

  -- pump control via mosfet
  gpio.mode(PIN_PUMP, gpio.OUTPUT)

  -- register for pump commands
  G.mqtt.subscribe("switch/pump", function(data)
    if(data == "1") then
      module.start_pump()
    else
      module.stop_pump()
    end
  end)

  -- turn off the pump on startup
  module.stop_pump()
end

-- run the application
function module.start()
  setup()
end

return module
