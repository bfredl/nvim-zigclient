mod = loadfile 'lua/zigclient/init.lua' ()
b = loadfile 'lua/zigclient/bundle.lua' ()
s = mod.zig_server('/home/bfredl/dev/forklift/src/run_ir.zig', false)
s = mod.zig_server('/home/bfredl/dev/forklift/src/FLIR.zig', true)
base_path = '/home/bfredl/dev/forklift/src'
s:send(s.client_messages.update)
s._body
e = b.process_bundle(s.err_bundle)
di = b.msg_to_diag(e[1], base_path)
msg = e[1]
t = mod.start_server(s.bin_path, {"--listen=-"})
s.err_bundle
t:send(t.client_messages.query_test_metadata)
t.test_metadata[19+1]
md = mod.parse_test_metadata(t.test_meta_body)
#md

string.sub("\0ab", 2)
t:send(t.client_messages.exit)
t:run_test(20)
t
t.test_res_body


s:send(s.client_messages.exit)
s:send(s.client_messages.exit)
s:send(s.client_messages.query_test_metadata)
s.err_bundle
