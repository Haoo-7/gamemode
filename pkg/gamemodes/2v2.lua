local desc_2v2 = [[
  # 2v2简介

  游戏由两名忠臣和两名反贼进行，胜利目标为击杀所有敌人。

  座位排列固定是忠-反-反-忠。

  一名角色死亡后，其队友会摸一张牌。

  第一回合角色摸牌阶段少摸一张牌。四号位多摸一张初始手牌。

  队友手牌可见。
]]

---@param room Room
local function summonBots(room)
  local lord = room.players[1]
  local nonlord = room.players[2]
  local p1 = room:summonPlayer(lord, nonlord, {
    skip_preparation = true, send_log = false,
  })
  ---@cast p1 -nil
  local p2 = room:summonPlayer(nonlord, nonlord, {
    skip_preparation = true, send_log = false,
  })
  ---@cast p2 -nil

  room:swapSeat(nonlord, p1, false)
end

local m_2v2_getLogic = function()
  ---@class m2v2Logic: GameLogic
  local m_2v2_logic = GameLogic:subclass("m_2v2_logic")

  function m_2v2_logic:assignRoles()
    ---@return ServerPlayer[]
    local function getOtherPlayers(room, p)
      local ret = table.simpleClone(room.players)
      table.removeOne(ret, p)
      return ret
    end

    local function getPlayerByScreenName(room, name)
      return table.find(room.players, function(p)
        return p._splayer:getScreenName() == name
      end)
    end

    local room = self.room

    if #room.players == 2 then
      room:setBanner("is_2v2_duel", true)
      -- 因为一控多不支持刷卡，所以ban手气卡
      room.settings._game.luckTime = 0
      summonBots(room)
    end

    local croom = room.room
    local cowner = croom:getOwner()
    local owner = getPlayerByScreenName(room, cowner:getScreenName())
    local buddy
    if not room:getBanner("is_2v2_duel") then
      buddy = room:askToChoosePlayers(owner, {
        min_num = 1,
        max_num = 1,
        targets = getOtherPlayers(room, owner),
        skill_name = "game_rule",
        prompt = "#m_2v2_choose_buddy",
        cancelable = true,
        no_indicate = true,
      })[1]
    else
      buddy = table.find(getOtherPlayers(room, owner), function(p)
        return p.id < 0 and p.serverplayer == cowner
      end)
    end

    if buddy then
      local buddy_table = { 4, 3, 2, 1 }
      local owner_seat = math.random(1, 4)
      local buddy_seat = buddy_table[owner_seat]
      local others = getOtherPlayers(room, owner)
      table.removeOne(others, buddy)
      table.shuffle(others)
      local players = {}
      players[owner_seat] = owner
      players[buddy_seat] = buddy
      if owner_seat == 1 or owner_seat == 4 then
        players[2] = others[1]
        players[3] = others[2]
      else
        players[1] = others[1]
        players[4] = others[2]
      end
      room.players = players
    else
      table.shuffle(room.players)
    end

    local n = #room.players

    local roles = { "loyalist", "rebel", "rebel", "loyalist" }

    for i = 1, n do
      local p = room.players[i]
      p.role = roles[i]
    end

    ---[[
    room.players[1]:addBuddy(room.players[4])
    room.players[4]:addBuddy(room.players[1])
    room.players[2]:addBuddy(room.players[3])
    room.players[3]:addBuddy(room.players[2])
    --]]
    --
    self.start_role = roles[1]
    -- for adjustSeats
    room.players[1].role = "lord"
  end

  function m_2v2_logic:chooseGenerals()
    local room = self.room
    local generalNum = math.min(room:getSettings('generalNum'), 9)

    local lord = room:getLord()
    room:setCurrent(lord)
    lord.role = self.start_role
    for _, p in ipairs(room.players) do
      room:setPlayerProperty(p, "role_shown", true)
      room:broadcastProperty(p, "role")
    end

    local nonlord = room.players
    local generals = table.map(Fk:getGeneralsRandomly(#nonlord * generalNum), Util.NameMapper)
    table.shuffle(generals)
    local t1 = table.slice(generals, 1, generalNum + 1)
    local t2 = table.slice(generals, generalNum + 1, generalNum * 2 + 1)
    local t3 = table.slice(generals, generalNum * 2 + 1, generalNum * 3 + 1)
    local t4 = table.slice(generals, generalNum * 3 + 1, generalNum * 4 + 1)
    if room:getBanner("is_2v2_duel") then
    local cool_marshal = room.players[1]
    local warm_marshal = room.players[2]
    local req = Request:new({cool_marshal, warm_marshal}, "AskForGeneral")
    req.timeout = self.room:getSettings('generalTimeout')
      local cool_generals = table.connect(t1, t4)
      req:setData(cool_marshal, { cool_generals, 2 })
      req:setDefaultReply(cool_marshal, room:tableRandomPick(cool_generals, 3))
      local warm_generals = table.connect(t2, t3)
      req:setData(warm_marshal, { warm_generals, 2 })
      req:setDefaultReply(warm_marshal, room:tableRandomPick(warm_generals, 3))

      room:doBroadcastNotify("ShowToast",
        Fk:translate("2v2_duel_choose_general"),
        {cool_marshal, warm_marshal})
      req:ask()

      local glist = {}
      table.insert(glist, req:getResult(cool_marshal)[1])
      table.insertTable(glist, req:getResult(warm_marshal))
      table.insert(glist, req:getResult(cool_marshal)[2])

      for i = 1, 4, 1 do
        local p = room.players[i]
        room:setPlayerGeneral(p, glist[i], true, true)
        room:findGeneral(glist[i])
      end
    else
      local req = room:askToMiniGame(nonlord, {
        skill_name = "AskForGeneral",
        game_type = "2v2_sel",
        data_table = {
          [nonlord[1].id] = {
            friend_id = nonlord[4].id,
            me = t1, friend = t4,
          },
          [nonlord[2].id] = {
            friend_id = nonlord[3].id,
            me = t2, friend = t3,
          },
          [nonlord[3].id] = {
            friend_id = nonlord[2].id,
            me = t3, friend = t2,
          },
          [nonlord[4].id] = {
            friend_id = nonlord[1].id,
            me = t4, friend = t1,
          },
        },
        timeout = self.room:getSettings('generalTimeout'),
      })
      for _, p in ipairs(nonlord) do
        local general = req:getResult(p)
        room:setPlayerGeneral(p, general, true, true)
        room:findGeneral(general)
      end
    end

    room:askToChooseKingdom(nonlord)
  end

  function m_2v2_logic:attachSkillToPlayers()
    GameLogic.attachSkillToPlayers(self)

    local room = self.room
    if room:getSettings("enableLimitFeiyang") then
      room:handleAddLoseSkills(room.players[4], "m_2v2_feiyang", nil, false)
    end
  end

  return m_2v2_logic
end

local m_2v2_mode = fk.CreateGameMode{
  name = "m_2v2_mode",
  minPlayer = 2,
  maxPlayer = 4,
  rule = "#m_2v2_rule&",
  feasible = function(self, settings)
    local players = settings.playerNum
    return players == 2 or players == 4
  end,
  logic = m_2v2_getLogic,
  main_mode = "2v2_mode",
  surrender_func = function(self, playedTime)
    -- 若为统率 沿用1v1投降
    if Fk:currentRoom():getBanner("is_2v2_duel") then
      return { { text = "time limitation: 1 min", passed = playedTime >= 60 } }
    end
    local surrenderJudge = { { text = "time limitation: 1 min", passed = playedTime >= 60 },
    { text = "2v2: left you alive", passed = table.find(Fk:currentRoom().players, function(p)
      return p.role == Self.role and p.dead and p.rest == 0
    end) and true } }
    return surrenderJudge
  end,
  winner_getter = function(self, victim)
    -- 若为统率 直接结束游戏
    if victim.surrendered and Fk:currentRoom():getBanner("is_2v2_duel") then
      return victim.role == "loyalist" and "rebel" or "loyalist"
    end
    if not victim.surrendered and victim.rest > 0 then
      return ""
    end

    local room = victim.room
    local alive = table.filter(room.players, function(p) ---@type Player[]
      return not p.surrendered and not (p.dead and p.rest == 0)
    end)
    local winner = alive[1].role
    for _, p in ipairs(alive) do
      if p.role ~= winner then
        return ""
      end
    end
    return winner
  end,
  reward_punish = function (self, victim, killer)
    local room = victim.room
    for _, p in ipairs(room.alive_players) do
      if p.role == victim.role and not p.dead then
        p:drawCards(1, "game_rule")
      end
    end
  end,
}

local W = require "ui_emu.preferences"
m_2v2_mode.ui_settings = {
  W.PreferenceGroup {
    title = "Game Rule",

    W.SwitchRow {
      _settingsKey = "enableLimitFeiyang",
      title = "m_2v2_limit_feiyang",
    },
  },

  W.PreferenceGroup {
    title = "",
    W.SwitchRow {
      _settingsKey = "_unused1",
      title = "2v2_2player",
      enabled = false,
    }
  },
}

Fk:loadTranslationTable{
  ["m_2v2_mode"] = "2v2",
  [":m_2v2_mode"] = desc_2v2,

  ["#m_2v2_choose_buddy"] = "请房主选择自己的队友",

  ["time limitation: 1 min"] = "游戏时长达到1分钟",
  ["2v2: left you alive"] = "你所处队伍仅剩你存活",

  ["m_2v2_limit_feiyang"] = "四号位获得〖飞扬〗",
  ["help: m_2v2_limit_feiyang"] = "(OL) 四号位增加需弃两张手牌的、限定技版的〖飞扬〗",
  ["#m_2v2_feiyang-invoke"] = "飞扬：你可以弃置两张手牌，弃置自己判定区的一张牌",

  ["2v2_2player"] = "“统率二军”",
  ["help: 2v2_2player"] = "游戏人数可以调成2，此时为“统率二军”模式 (此开关仅供提示)",

  ["2v2_duel_choose_general"] = "请为本方阵营选择选择武将，从左至右为一四（或二三）",
}

Fk:addMiniGame{
  name = "2v2_sel",
  qml_path = "packages/gamemode/qml/2v2",
  default_choice = function(player, data)
    return data.me[1]
  end,
  update_func = function(player, data)
    local room = player.room
    local d = player.mini_game_data.data
    local friend = room:getPlayerById(d.friend_id)
    friend:doNotify("UpdateMiniGame", data)
  end,
}

return m_2v2_mode
