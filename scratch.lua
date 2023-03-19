loadfile 'lua/zigclient/init.lua'
s = _mod_zigclient.start_server('/home/bfredl/dev/forklift/src/run_ir.zig', false)
s:send(s.client_messages.update)
s:send(s.client_messages.exit)
s.err_bundle
}
