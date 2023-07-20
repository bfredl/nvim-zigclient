local h = _G._mod_zigclient_bundle or {}
_G._mod_zigclient_bundle = h

function h.process_srcloc(s)
  return {
    col = s.col;
    line = s.line;
    col_start = s.col - (s.span_main - s.span_start);
    col_end = s.col + (s.span_end - s.span_main);
    src_path = s.src_path;
  }
end

function h.process_bundle(bundle)
  msgs = {}
  for _,msg in ipairs(bundle) do
    local main = h.process_srcloc(msg.src_loc)
    main.msg = msg.msg
    local notes = {}
    for _,note in ipairs(msg.notes) do
      local n = h.process_srcloc(note.src_loc)
      n.msg = note.msg
      table.insert(notes, n);
    end
    local reftrace = {}
    for _,pos in ipairs(msg.src_loc.ref_trace) do
      local p = h.process_srcloc(pos.src_loc)
      p.decl_name = pos.decl_name
      table.insert(reftrace, p);
    end
    table.insert(msgs, {main=main,notes=notes,reftrace=reftrace})
  end
  return msgs
end

function h.is_in_base(msg_item, base_path)
  if not vim.startswith(msg_item.src_path, '/') then
    return true -- DUBBEL bULL
  end
  return vim.startswith(msg_item.src_path, base_path) -- BULL
end

function h.item_to_diag(item, kind, main)
  local diag = {
    bufnr = vim.fn.bufadd(item.src_path);
    lnum = item.line;
    col = item.col_start;
    end_col = item.col_end;
    -- TODO: main col lol
    message = item.msg;
  }
  if kind == "error" then
    diag.severity = vim.diagnostic.severity.ERROR;
  elseif kind == "error_base" then
    diag.message = "HABLA: "..main.msg
    diag.severity = vim.diagnostic.severity.ERROR;
  elseif kind == "ref" then
    diag.message = "Referenced here"
    diag.severity = vim.diagnostic.severity.INFO;
    -- TODO: do something so we can jump there
    -- diag.user_data = main
  else
    diag.severity = vim.diagnostic.severity.INFO;
  end
  return diag
end

function h.msg_to_diag(msg, base_path, diags)
  diags = diags or {}
  local base_loc
  if h.is_in_base(msg.main, base_path) then
    base_loc = msg.main
    table.insert(diags, h.item_to_diag(msg.main, "error"))
  end
  for _, item in ipairs(msg.reftrace) do
    if h.is_in_base(item, base_path) then
      if base_loc == nil then
        base_loc = item
        table.insert(diags, h.item_to_diag(item, "error_base", msg.main))
      else
        table.insert(diags, h.item_to_diag(item, "ref", msg.main))
      end
    end
  end
  for _, item in ipairs(msg.notes) do
    if h.is_in_base(item, base_path) then
        table.insert(diags, h.item_to_diag(item, "note", msg.main))
    end
  end
  return diags
end

function h.bundle_to_diags(bundle, base_path)
  diags = {}
  for _,msg in ipairs(bundle) do
    h.msg_to_diag(msg, base_path, diags)
  end
  return diags
end

return h
