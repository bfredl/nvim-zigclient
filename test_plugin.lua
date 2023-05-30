local h = require 'zigclient'
local b = require 'zigclient.bundle'
local ns = vim.api.nvim_create_namespace 'zigclient'
base_path = vim.loop.cwd()
function doit(kind, value)
  if kind == h.server_messages.error_bundle then
    bundle = b.process_bundle(value)
    theerr = b.bundle_to_diags(bundle, base_path)
    print("errors!")
  elseif kind == h.server_messages.emit_bin_path then
    theerr = {}
    print("good!")
  end
end
s = h.start_server("zig", {'build-exe', '-lc', vim.api.nvim_buf_get_name(0), '-freference-trace', '--listen=-'}, doit)
function update()
  vim.cmd 'update'
  s:update()
end
