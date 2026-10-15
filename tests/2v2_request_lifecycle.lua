-- Run from the gamemode package root with Lua 5.4; uses no game/account database.
local path = "pkg/gamemodes/2v2.lua"
local file = assert(io.open(path, "rb"))
local source = file:read("a")
file:close()
local first = assert(source:find("local function m_2v2_askMiniGame(", 1, true))
local last = assert(source:find("\n--- ", first, true))
local context = setmetatable({
  cbor = { encode = function(value) return value end },
}, { __index = _G })
context.table = setmetatable({
  find = function(values, predicate)
    for _, value in ipairs(values) do
      if predicate(value) then return value end
    end
  end,
}, { __index = table })
local ask = assert(load(source:sub(first, last - 1)
  .. "\nreturn m_2v2_askMiniGame", path, "t", context))()

local function test(dual, timedOut)
  local events, controllers, players = {}, {}, {}
  for i = 1, 4 do
    local controllerId = dual and (i == 4 and 1 or i == 3 and 2 or i) or i
    controllers[controllerId] = controllers[controllerId] or {
      doNotify = function(_, command)
        assert(command == "CancelRequest")
        events[#events + 1] = "cancel:" .. controllerId
      end,
    }
    players[i] = { id = i, serverplayer = controllers[controllerId] }
  end
  local targets = dual and { players[1], players[2] } or players
  local params = { game_type = "2v2_sel", data_table = {} }
  for _, p in ipairs(targets) do params.data_table[p.id] = { me = {"test_general"} } end
  local req = { timedOut = timedOut }
  local room = {
    players = players,
    askToMiniGame = function(_, received, data)
      assert(received == targets and data == params)
      for _, p in ipairs(players) do assert(p.mini_game_data.type == "2v2_sel") end
      events[#events + 1] = "answered_or_timed_out"
      return req
    end,
  }
  assert(ask(room, targets, params) == req)
  assert(events[1] == "answered_or_timed_out")
  assert(#events == #targets + 1)
  for _, p in ipairs(players) do assert(p.mini_game_data == nil) end
  -- The next GameStart/kanpo request can only be sent after all old UIs are reset.
  events[#events + 1] = "next_skill_request"
  assert(events[#events - 1]:find("cancel:", 1, true) == 1)
end

test(false, false)
test(false, true)
test(true, false)
test(true, true)
assert(source:find('local req = m_2v2_askMiniGame(room, nonlord, {', 1, true),
  "Four-player final selection must use the cleanup wrapper")
print("PASS: four-player/dual-control selection, normal replies/timeouts, cleanup ordering and request result")
