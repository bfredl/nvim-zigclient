local h = _G._mod_zigclient or {}
_G._mod_zigclient = h

local has_luadev, luadev = pcall(require, "luadev")
local print = has_luadev and luadev.print or _G.print

h.client_messages = {
  exit = 0;
  update = 1;
  run = 2;
  hot_update = 3;
  query_test_metadata = 4;
  run_test = 5;
}

h.server_messages = {
  zig_version = 0;
  error_bundle = 1;
  progress = 2;
  emit_bin_path = 3;
  test_metadata = 4;
  test_results = 5;
}

local ffi = require'ffi'
function u32(bytes, where)
  return ffi.cast('uint32_t*', bytes)[where or 0]
end

function h.parse_output(self)
  while true do
    if self.data == nil or #self.data < 8 then
      return
    end
    local kind = u32(string.sub(self.data, 1, 4))
    local len = u32(string.sub(self.data, 5, 8))
    if #self.data < 8+len then
      return
    end
    print("msg:", kind, len)

    local body = string.sub(self.data,9, 8+len) -- there's a body alright
    local nxt = string.sub(self.data,9+len)
    self.data = #nxt > 0 and nxt or nil

    local s = h.server_messages
    if kind == s.zig_version then
      self.zig_version = body
    elseif kind == s.progress then
      print("progress:", body)
    elseif kind == s.emit_bin_path then
      self.bin_path = body
      if string.sub(self.bin_path, 1, 1) == '\0' then
        self.bin_path = string.sub(self.bin_path,2)
      end
    elseif kind == s.error_bundle then
      self.err_body = body
      self.err_bundle = parse_errors(body)
    elseif kind == s.test_metadata then
      self.test_meta_body = body
      self.test_metadata = self.parse_test_metadata(body)
    elseif kind == s.test_results then
      self.test_res_body = body
    end
  end
end

function parse_errors(body)
  extra_len = u32(body)
  string_bytes_len = u32(body,1)
  extra_data = string.sub(body,9,8+extra_len*4)
  string_data = string.sub(body,8+extra_len*4+1)
  extra = ffi.cast('uint32_t*', extra_data)
  string_bytes = ffi.cast('char*', string_data)

  eml_len = extra[0]
  eml_start = extra[1]
  eml_log_text = extra[2]

  local function src_loc(src_at, rec)
    if src_at == 0 then return {} end
    local reference_trace_len = extra[src_at+7]
    local srcref_at = src_at+8
    local ref_trace = {}
    local ref_hidden = nil
    for i = 1,reference_trace_len do
      ref_decl_name = extra[srcref_at+2*(i-1)+0]
      ref_src_loc = extra[srcref_at+2*(i-1)+1]
      if ref_src_loc ~= 0 then
        ref_decl = ffi.string(string_bytes+ref_decl_name)
        if rec then -- format in theory allows recursive traces, assume such maddnes won't be needed for now
          ref_src_loc = src_loc(ref_src_loc, false)
        end
        table.insert(ref_trace, {decl_name=ffi.string(string_bytes+ref_decl_name), src_loc=ref_src_loc})
      else
        ref_hidden = ref_decl_name
      end
    end
    return {
      src_path = ffi.string(string_bytes+extra[src_at]);
      line = extra[src_at+1];
      col = extra[src_at+2];
      span_start = extra[src_at+3];
      span_main = extra[src_at+4];
      span_end = extra[src_at+5];
      source_line = ffi.string(string_bytes+extra[src_at+6]);
      ref_trace = ref_trace;
      ref_hidden = ref_hidden;
    }
  end

  local function message(msg_at, rec)
    local msg = {
      msg = ffi.string(string_bytes+extra[msg_at]);
      count = extra[msg_at+1];
      src_loc = src_loc(extra[msg_at+2], true);
      notes = {}
    }
    local notes_len = extra[msg_at+3];
    local notes_at = msg_at+4
    for i = 1,notes_len do
      local note = extra[notes_at+i-1]
        if rec then -- format in theory allows recursive notes, assume such maddnes won't be needed for now
          note = message(note, false)
        end
        table.insert(msg.notes, note)
    end
    return msg
  end

  local messages = {}
  for msgid = 1,eml_len do
    local msg_at = extra[eml_start+msgid-1]
    table.insert(messages, message(msg_at, true))
  end

  return messages
end

function h.parse_test_metadata(body)
  string_bytes_len = u32(body)
  tests_len = u32(body,1)
  name_data = string.sub(body,9,8+tests_len*4)
  async_frame_len_data = string.sub(body,9+tests_len*4,8+tests_len*8)
  expected_panic_data = string.sub(body,9+tests_len*8,8+tests_len*12)
  string_data = string.sub(body,9+tests_len*12,8+tests_len*12+string_bytes_len)
  string_bytes = ffi.cast('char*', string_data)

  tests = {}
  for i = 1,tests_len do
    expected_panic_idx = u32(expected_panic_data, i-1);
    table.insert(tests, {
      name = ffi.string(string_bytes+u32(name_data, i-1));
      async_frame_len = u32(async_frame_len_data, i-1);
      expected_panic_msg = expected_panic_idx > 0 and ffi.string(string_bytes+expected_panic_idx) or nil;
    })
  end
  return tests
end

h.__index = h

local uv = vim.loop
function h.start_server(cmd, args)
  local self = setmetatable({}, h)
  self.stdin = uv.new_pipe(false)

  self.stderr_hnd = uv.pipe()
  self.stderr = uv.new_pipe()
  self.stderr:open(self.stderr_hnd.read)
  self.stderr:read_start(vim.schedule_wrap(function(err,data)
    if data then print(data) end
  end))

  self.data = nil

  self.stdout_hnd = uv.pipe()
  self.stdout = uv.new_pipe()
  self.stdout:open(self.stdout_hnd.read)
  self.stdout:read_start(function(err,data)
    if not data then
      return
    end

    -- TODO: check if luajit handles ''..data === data w/o copy
    if self.data then
      self.data = self.data .. data
    else
      self.data = data
    end
    vim.schedule(function() self:parse_output() end)
  end)

  vim.print(args)

  self.handle, self.pid = uv.spawn(cmd, {
    args = args,
    stdio = {self.stdin, self.stdout_hnd.write, self.stderr_hnd.write}
  }, vim.schedule_wrap(function()
    print("server exit")
  end))

  return self
end

function h.zig_server(entrypoint, test)
  local subcmd = test and 'test' or 'build-exe'
  args = {
    subcmd;
    -- '-fno-emit-bin';
   entrypoint;
    "--listen=-";
  }
  return h.start_server("zig", args)
end

function h:send(msg, data)
  if type(msg) == 'string' then
    msg = h.client_messages[msg]
  end
  data = data or ''
  local header = ffi.new("uint32_t[2]")
  header[0] = msg
  header[1] = #data
  header = ffi.string(header,8)
  self.stdin:write(header)
  if #data > 0 then
    self.stdin:write(data)
  end
end

function h:run_test(nr)
  local body = ffi.new("uint32_t[1]")
  body[0] = nr
  body = ffi.string(body,4)
  return self:send(h.client_messages.run_test, body)
end

return h
