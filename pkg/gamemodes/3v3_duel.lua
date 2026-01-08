local desc_33 = [[
  # 统率三军模式简介

  详见3v3模式规则。由于无法做到令一个房间只能开2人局/6人局，因此统率模式独立了出来。

  不过这个模式将池不限制白名单，日后再看看如何作为一个开关修改。
]]


local mode3v3 = require "packages.gamemode.pkg.gamemodes.3v3"

local m_3v3_duel_getLogic = function()
  local logic3v3 = mode3v3.logic()
  local m_3v3_duel_logic = logic3v3:subclass("m_3v3_duel_logic")

  function m_3v3_duel_logic:initialize(room)
    logic3v3.initialize(self, room)
    -- FIXME 因为一控多不支持刷卡，所以直接写死0
    room.settings._game.luckTime = 0
  end

  -- 3v3修改：发身份前先召唤人机
  function m_3v3_duel_logic:assignRoles()
    local room = self.room
    local roles = self.role_table[1]
    table.shuffle(room.players)

    local lord = room.players[1]
    local nonlord = room.players[2]

    local function summonFriends(player)
      local p1 = room:summonPlayer(player, player, {
        skip_preparation = true, send_log = false,
      })
      ---@cast p1 -nil
      local p2 = room:summonPlayer(player, player, {
        skip_preparation = true, send_log = false,
      })
      ---@cast p2 -nil

      room:swapSeat(player, p2, false)

      p1:addBuddy(p2)
      p1:addBuddy(player)
      p2:addBuddy(p1)
      p2:addBuddy(player)
      player:addBuddy(p1)
      player:addBuddy(p2)
    end

    summonFriends(lord)
    summonFriends(nonlord)

    for i = 1, #room.players do
      local p = room.players[i]
      p.role = roles[i]
      room:setPlayerProperty(p, "role_shown", true)
      room:broadcastProperty(p, "role")
    end
    room:setCurrent(room.players[1])
  end

  -- 其他和3v3都一样！

  return m_3v3_duel_logic
end

local m_3v3_duel_mode = fk.CreateGameMode{
  name = "m_3v3_duel_mode",
  minPlayer = 2,
  maxPlayer = 2,
  logic = m_3v3_duel_getLogic,
  rule = "#m_3v3_rule&",
  surrender_func = function(self, playedTime)
    -- 投降不一样 沿用1v1投降
    return { { text = "time limitation: 2 min", passed = playedTime >= 120 } }
  end,
  -- whitelist先不沿用
  winner_getter = mode3v3.getWinner,
  get_adjusted = mode3v3.getAdjustedProperty,
  build_draw_pile = mode3v3.buildDrawPile,
  reward_punish = mode3v3.deathRewardAndPunish,
  friend_enemy_judge = mode3v3.friendEnemyJudge,
}
Fk:loadTranslationTable{
  ["m_3v3_duel_mode"] = "统率三军",
  [":m_3v3_duel_mode"] = desc_33,
}

return m_3v3_duel_mode
