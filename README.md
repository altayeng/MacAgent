# MacAgent
Control Macbook's cam over mqtt server.  

On default, it connects to "mqtt-dashboard.com" host on 1883 port, and listening "MacAgent" topics. You can send "on" or "off" messages from host. 
Every "on" receives, Mac's cam taking a photo as a string and sending it to the same topic. 
