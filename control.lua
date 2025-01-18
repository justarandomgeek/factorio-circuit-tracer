---@class (exact) tracer_storage
---@field probes table<integer,TracerProbe>
---@field trace? TraceData
storage = {
  probes = {},
}

---@class TracerProbe
---@field entity LuaEntity
---@field unit_number integer
---@field label string?

---@alias WireTraceValues<T> {[QualityID]:{[SignalIDType]:{[string]:T}}}
---@alias TraceValues {[integer]:{[defines.wire_connector_id]:WireTraceValues<int32>}}

---@class TraceData
---@field start uint64
---@field last TraceValues # last seen values, also serves as list of all seen signals when it's time to write out a file
---@field changes {tick:uint64, values:TraceValues}[] 



script.on_configuration_changed(function(config_changed)
  if not storage.probes then
    storage.probes = {}
  end
end)

---@generic K,V
---@param t table<K,V>
---@param k K
---@return V
local function get_or_create(t,k)
  local v = t[k]
  if not v then
    v = {}
    t[k] = v
  end
  return v
end

---@param last WireTraceValues<int32>
---@param seen WireTraceValues<boolean>
---@param signal Signal
local function is_new_value(last, seen, signal)
  local sig = signal.signal
  local q = sig.quality or "normal"
  local t = sig.type or "item"
  local tlast = get_or_create(get_or_create(last, q), t)
  local tseen = get_or_create(get_or_create(seen, q), t)

  local n = sig.name
  ---@cast n -?
  tseen[n] = true

  local clast = tlast[n]
  if clast ~= signal.count then
    tlast[n] = signal.count
    return true
  end
  return false
end

local wires = { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }
local wires_with_out = {
  defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green,
  defines.wire_connector_id.combinator_output_red, defines.wire_connector_id.combinator_output_green
}

local has_out = {
  ["arithmetic-combinator"] = true,
  ["decider-combinator"] = true,
  ["selector-combinator"] = true,
}

script.on_event(defines.events.on_tick, function()
  local trace = storage.trace
  if not trace then return end

  local last = trace.last
  ---@type TraceValues
  local tickchanges = {}
  local has_event = false

  local probes = storage.probes
  for key, probe in pairs(probes) do
    local entity = probe.entity
    if not (entity and entity.valid) then
      probes[key] = nil
    else
      local pid = entity.unit_number
      local plast = get_or_create(last, pid)

      local wids = has_out[entity.type] and wires_with_out or wires
      for _, wireid in pairs(wids) do
        local signals = entity.get_signals(wireid)

        --- signals seen this tick
        ---@type WireTraceValues<boolean>
        local wseen = {}

        --- last seen values of signals
        ---@type WireTraceValues<int32>?
        local wlast = plast[wireid]

        --- change events for this tick
        ---@type WireTraceValues<int32>?
        local wtrace

        if signals then
          -- don't bother recording a wire's "last seen" at all until it actually has a signal on it...
          if not wlast then
            wlast = {}
            plast[wireid] = wlast
          end
          for _, signal in pairs(signals) do
            if is_new_value(wlast, wseen, signal) then
              if not wtrace then
                wtrace = get_or_create(get_or_create(tickchanges, pid), wireid)
              end
              local sig = signal.signal
              get_or_create(get_or_create(wtrace, sig.quality or "normal"), sig.type or "item")[sig.name] = signal.count
              has_event = true
            end
          end
        end

        if wlast then
          --zero any in wlast not marked in wseen
          for q, qlast in pairs(wlast) do
            local qseen = wseen[q]
            ---@cast qseen +?
            for t, tlast in pairs(qlast) do
              local tseen = qseen and qseen[t]
              for name, value in pairs(tlast) do
                if value ~= 0 and not (tseen and tseen[name]) then
                  if not wtrace then
                    wtrace = get_or_create(get_or_create(tickchanges, pid), wireid)
                  end
                  
                  tlast[name] = 0
                  get_or_create(get_or_create(wtrace, q), t)[name] = 0
                  has_event = true
                end
              end
            end
          end
        end

      end
    end
  end

  if has_event then
    trace.changes[#trace.changes+1] = { tick = game.tick, values = tickchanges }
  end
end)

commands.add_command("CTbind", "", function(param)
  if storage.trace then return end
  local ent = game.get_player(param.player_index).selected
  if ent and ent.unit_number then
    storage.probes[ent.unit_number] = {
      entity = ent,
      unit_number = ent.unit_number,
      label = param.parameter
    }
  end
end)

commands.add_command("CTunbind", "", function(param)
  if storage.trace then return end
  local ent = game.get_player(param.player_index).selected
  if ent and ent.unit_number then
    storage.probes[ent.unit_number] = nil
  end
end)

commands.add_command("CTshow", "", function(param)
  rendering.clear("circuit-tracer")
  for _, probe in pairs(storage.probes) do
    rendering.draw_circle{
      color = {r=0.3, g=0.3, b=1},
      radius = .5,
      surface = probe.entity.surface,
      target = probe.entity,
      time_to_live = 300,
    }
    rendering.draw_text{
      text = probe.label or tostring(probe.entity.unit_number),
      color = {r=0.3, g=0.3, b=1},
      orientation = 1/10,
      surface = probe.entity.surface,
      target = {
        entity = probe.entity,
      }--[[@as ScriptRenderTargetTable]],
      time_to_live = 300,
    }
  end
end)

commands.add_command("CTclear", "", function(param)
  storage.trace = nil
  storage.probes = {}
end)

commands.add_command("CTstart", "", function(param)
  storage.trace = {
      start = game.tick,
      last = {},
      changes = {},
    }
end)

local hexbits = {
  ["0"]="0000",
  ["1"]="0001",
  ["2"]="0010",
  ["3"]="0011",
  ["4"]="0100",
  ["5"]="0101",
  ["6"]="0110",
  ["7"]="0111",
  ["8"]="1000",
  ["9"]="1001",
  ["a"]="1010",
  ["b"]="1011",
  ["c"]="1100",
  ["d"]="1101",
  ["e"]="1110",
  ["f"]="1111",
}

---@param n int32
---@return string
local function int_to_bin(n)
  if n == 0 then 
    return "z"
  end
  return (string.gsub(string.sub(string.format("%x", n), -8), "%x", hexbits))
end

local wirename = {
  "red", "green", "outred", "outgreen"
}

commands.add_command("CTstop", "", function(param)
  local trace = storage.trace
  if not trace then return end

  ---@type string[]
  local out = {}

  ---@type TraceValues
  local ids = {}
  local nextid = 1

  local probes = storage.probes

  for pid, ptrace in pairs(trace.last) do
    local plabel = probes[pid].label
    if plabel then
      out[#out+1] = string.format("$scope module %s $end", plabel)
    else
      out[#out+1] = string.format("$scope module probe_%d $end", pid)
    end
    local pids = get_or_create(ids, pid)
    for wireid, wtrace in pairs(ptrace) do
      out[#out+1] = string.format("$scope module %s $end", wirename[wireid])
      local wids = get_or_create(pids, wireid)
      for qual, qtrace in pairs(wtrace) do
        out[#out+1] = string.format("$scope module %s $end", qual)
        local qids = get_or_create(wids, qual)
        for sigtype, ttrace in pairs(qtrace) do
          out[#out+1] = string.format("$scope module %s $end", sigtype)
          local tids = get_or_create(qids, sigtype)
          for name, value in pairs(ttrace) do
            local id = nextid
            nextid = nextid + 1
            tids[name] = id
            out[#out+1] = string.format("$var wire 32 %x %s $end", id, name)
          end
          out[#out+1] = "$upscope $end"
        end
        out[#out+1] = "$upscope $end"
      end
      out[#out+1] = "$upscope $end"
    end
    out[#out+1] = "$upscope $end"
  end
  out[#out+1] = "$enddefinitions $end"

  local start = trace.start
  for _, changes in pairs(trace.changes) do
    local t = changes.tick - start
    out[#out+1] = string.format("#%d", t)

    for pid, pchanges in pairs(changes.values) do
      for wireid, wchanges in pairs(pchanges) do
        for qid, qchanges in pairs(wchanges) do
          for tid, tchanges in pairs(qchanges) do
            for name, value in pairs(tchanges) do
              local id = ids[pid][wireid][qid][tid][name]
              out[#out+1] = string.format("b%s %x", int_to_bin(value), id or 0 )
            end
          end
        end
      end
    end

  end

  helpers.write_file(string.format("trace_%d.vcd", start), table.concat(out, "\n"))

  storage.trace = nil
end)