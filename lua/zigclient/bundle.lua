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
      p.decl_name = note.decl_name
      table.insert(reftrace, p);
    end
    table.insert(msgs, {main=main,notes=notes,reftrace=reftrace})
  end
  return msgs
end

return h
