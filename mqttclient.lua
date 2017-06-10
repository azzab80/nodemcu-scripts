--
-- Manage and maintain a permanent connection to a MQTT broker
--
-- A connection is retried when it gets interrupted. Previous subscriptions
-- will be reregistered. Each subscription can have it's own callback
--
local module = {}

local m = nil -- the MQTT client
local subscriptions = {}
local connected = false


-- handle new connection
local function on_connect(con)
  connected = true

  -- (re)subscribe to to all topics
  for topic, cb in pairs(subscriptions) do
     m:subscribe(topic, 2)
  end

  print "MQTT connected"
end

-- handle disconnects
local function on_offline(client)
  connected = false

  -- try to reconnect in 10 seconds
  tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, connect)
  print "MQTT disconnected"
end

-- handle errors
local function on_error(client, reason)
  print("Error on MQTT connection. Reason " .. reason)
  on_offline(client)
end

-- handle messages
local function on_message(con, topic, data)
  if data ~= nil then
    print("MQTT message received: " .. topic .. ": " .. data)
    if subscriptions[topic] ~= nil then
      -- call callback with message
      subscriptions[topic](data)
    end
  end
end

-- send some data to the broker
--
-- @param string topic The (sub topic) to send the data to
-- @param mixed payload The actual payload to send
-- @param int qos optional quality of service
-- @param int retain can optionally be set to 1 to let the broker keep the value
--
function module.publish(topic, payload, qos, retain)
  qos = qos or 0
  retain = retain or 0

  if(connected) then
    m:publish(G.config.MQTT.endpoint .. topic, payload, 0, 0)
    print("MQTT", topic, payload)
  else
    print("currently not connected to MQTT broker, cannot publish to " .. topic)
  end
end

-- subscribe to topic
--
-- The given callback will be called when a message is received for
-- the topic. The message will be provided as the first parameter
--
-- @param {string} topic The subtopic to subscribe to
-- @param {function} callback Will be called for messages
--
function module.subscribe(topic, callback)
  subscriptions[G.config.MQTT.endpoint .. topic] = callback

  if(connected) then
    m:subscribe(G.config.MQTT.endpoint .. topic, 0)
  end
end

-- start MQTT connection
--
function module.start()
  connect()
end

return module

