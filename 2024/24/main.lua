#!/usr/bin/env lua

local function part1(input)
  local split_start <const>, split_end <const> = string.find(input, "\n\n")
  local wire_data <const> = string.sub(input, 1, split_start - 1)
  local gate_data <const> = string.sub(input, split_end, string.len(input) - 1)

  -- parse initial wire states
  local wires <const> = {}
  for line in string.gmatch(wire_data, "([^\n]+)") do
    local wire <const>, state <const> = string.match(line, "^(%g+):%s*([01])%s*$")
    assert(string.len(wire) >= 3)
    assert(state == "0" or state == "1")

    wires[wire] = {
      ['state']=state,
      ['source']=nil,
      ['sinks']={},
    }
  end

  -- parse gate connections
  local gates <const> = {}
  for line in string.gmatch(gate_data, "([^\n]+)") do
    local parts <const> = table.pack(string.match(line, "^(%g+)%s(%g+)%s(%g+)%s%->%s(%g+)$"))
    assert(#parts == 4)

    local input_a <const> = parts[1]
    local gate_type <const> = parts[2]
    local input_b <const> = parts[3]
    local output <const> = parts[4]

    table.insert(gates, {
      ['type']=gate_type,
      ['sources']={input_a, input_b},
      ['sink']=output,
    })

    local gate_index = #gates

    if not wires[output] then
      wires[output] = {
        ['state']='none',
        ['sinks']={},
      }
    end

    wires[output]['source'] = gate_index

    if not wires[input_a] then
      wires[input_a] = {
        ['state']='none',
        ['sinks']={},
      }
    end

    if not wires[input_b] then
      wires[input_b] = {
        ['state']='none',
        ['sinks']={},
      }
    end

    table.insert(wires[input_a]['sinks'], gate_index)
    table.insert(wires[input_b]['sinks'], gate_index)
  end

  -- simulate the system to evaluate all of the wire states
  local pending <const> = {}
  for wire, wire_data in pairs(wires) do
    assert(wire_data['state'] == '1' or wire_data['state'] == '0' or wire_data['state'] == 'none')

    if wire_data['state'] == 'none' then
      table.insert(pending, wire)
    end
  end

  while #pending > 0 do
    local output <const> = table.remove(pending, 1)
    local gate <const> = gates[wires[output]['source']]

    local input_a <const> = wires[gate['sources'][1]]['state']
    local input_b <const> = wires[gate['sources'][2]]['state']

    if input_a ~= 'none' and input_b ~= 'none' then
      if gate['type'] == 'AND' then
        wires[output]['state'] = (input_a == "1" and input_b == "1") and "1" or "0"
      elseif gate['type'] == 'OR' then
        wires[output]['state'] = (input_a == "1" or input_b == "1") and "1" or "0"
      else
        wires[output]['state'] = (input_a ~= input_b) and "1" or "0"
      end
    else
      table.insert(pending, output)
    end
  end

  -- locate all the wires that start with z
  local output_wires <const> = {}
  for wire, wire_data in pairs(wires) do
    if string.sub(wire, 1, 1) == "z" then
      table.insert(output_wires, wire)
    end
  end

  table.sort(output_wires, function (a, b)
    return (a > b)
  end)

  local binary_digits <const> = {}
  for _, wire in ipairs(output_wires) do
    local digit <const> = wires[wire]['state']
    assert(digit == "1" or digit == "0")

    table.insert(binary_digits, digit)
  end

  local binary_value <const> = table.concat(binary_digits, "")
  local decimal_value <const> = tonumber(binary_value, 2)

  -- return the computed value
  return decimal_value
end

local function run()
  local input_file <close> = assert(io.open('input', 'r'))
  local input <const> = assert(input_file:read('a'))
  assert(input_file:close())

  local part1_result = assert(part1(input))
  print("Part1:", part1_result)
end

run()
