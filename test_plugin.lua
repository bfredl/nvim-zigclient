local h = require 'zigclient'
local b = require 'zigclient.bundle'
local ns = vim.api.nvim_create_namespace 'zigclient'

base_path = vim.loop.cwd()
diag_bufs = {}
function set_multibuf_diags(diags)
  local bufdiag = {}
  for k,_ in pairs(diag_bufs) do
    bufdiag[k] = {}
  end
  for _,d in ipairs(diags) do
    bufdiag[d.bufnr] = bufdiag[d.bufnr] or {}
    table.insert(bufdiag[d.bufnr], d)
  end
  for b,d in pairs(bufdiag) do
    diag_bufs[b] = true
    vim.diagnostic.set(ns, b, d, {})
  end
end

function doit(kind, value)
  if kind == h.server_messages.error_bundle then
    bundle = b.process_bundle(value)
    theerr = b.bundle_to_diags(bundle, base_path)
    set_multibuf_diags(theerr)
    print("errors!")
  elseif kind == h.server_messages.emit_bin_path then
    theerr = {}
    set_multibuf_diags(theerr)
    print("good!")
  end
end
s = h.start_server("zig", {'build-exe', '-lc', vim.api.nvim_buf_get_name(0), '-freference-trace', '--listen=-'}, doit)
function update()
  vim.cmd 'update'
  s:update()
end
vim.keymap.set('n', '<Plug>ch:ir', '<cmd>lua update()<cr>')
