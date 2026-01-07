local desc_33 = [[
  # 统率三军模式简介

  两人进行对战的竞技化模式，进行车轮战，先死亡第三张武将的玩家失败，对手获胜。

  统率三军的规则比较复杂，正在开发中，目前提供一个简化版规则：

  - 系统为双方生成两名人机作为队友，你需要自己操控他们
  - 选将环节：抽取并明置16张武将，后方先选，按1-2-2-2-2-2-2-2-1交叉抓取。挑选完之后，从这八张武将中选择三张，这三张按照座位顺序分别会分配给你、你的队友1、你的队友2。
  - 固定按照忠反反忠忠反的行动顺序
  - 杀死一名角色摸两张牌（无论敌我）
  - 消灭对方阵营即可获胜

  （以下并未完成，只是展示一下实际上的规则）

  - 选将环节：同前，但是选取三张，按边锋-主帅-边锋顺序摆放
  - 主帅：血量上限+1。主帅死亡一方判输。后方主帅起手牌+1。
  - 边锋：击杀边锋者摸2张，无论敌我。
  - 行动环节：首轮由先手方主帅先动，再到后手方选择两个边锋动（自选先后顺序）或主帅动，再到先手边动，最后到后手方未行动的武将行动。所有活人动过一次，为一轮。下一轮由先手方选择两边动或主动，以此交叉类推。

  牌的变化：

  1. 拆、顺以及涉及己方手牌的技能，可以精确选择。例，精确顺队友手里的乐。
  2. 所有aoe（南万谷园）可以自选结算方向（顺逆时针方向）。
  3. 人数少的一方，无中生有额外摸1张。
  4. 连弩只能额外出3杀。
  5. 寒冰剑点数♠2改为♠A，  删除牌：♣2藤甲，♦Q无懈，两闪电，木牛流马。
]]

-- 从武将池中移除指定武将。若无法移除，则移去第一个武将
local function removeGeneral(generals, g)
  local gt = Fk.generals[g].trueName
  for i, v in ipairs(generals) do
    if Fk.generals[v].trueName == gt then
      return table.remove(generals, i)
    end
  end
  return table.remove(generals, 1)
end

local m_3v3_duel_getLogic = function()
  local m_3v3_duel_logic = GameLogic:subclass("m_3v3_duel_logic")

  function m_3v3_duel_logic:chooseGenerals()
    local room = self.room ---@type Room

    -- FIXME 因为一控多不支持刷卡，所以直接写死0
    self.room.settings._game.luckTime = 0

    local lord = room.players[1]
    room:setCurrent(lord)
    local nonlord = room.players[2]

    -- TODO 因为没做自选行动顺序，暂时按忠(p)反(p)反(p1)忠(p1)忠(p2)反(p2)行动
    -- 忠：L R -> L L1 R -> L L2 L1 R -> L R L1 L2
    -- 反：L R L1 L2 -> L R R1 L1 L2 -> L R R1 L1 R2 L2 -> L R R1 L1 L2 R2
    local function summonFriends(player)
      local p1 = room:summonPlayer(player, player == lord and nonlord or nonlord.next, {
        skip_preparation = true, send_log = false,
      })
      ---@cast p1 -nil
      local p2 = room:summonPlayer(player, player == lord and p1 or p1.next.next, {
        skip_preparation = true, send_log = false,
      })
      ---@cast p2 -nil

      if player == lord then
        room:swapSeat(nonlord, p2, false)
      else
        room:swapSeat(p2, p2.next, false)
      end
      p1:addBuddy(p2)
      p1:addBuddy(player)
      p2:addBuddy(p1)
      p2:addBuddy(player)
      player:addBuddy(p1)
      player:addBuddy(p2)
      room:setPlayerProperty(p1, "role", player.role)
      room:setPlayerProperty(p1, "role_shown", true)
      room:setPlayerProperty(p2, "role", player.role)
      room:setPlayerProperty(p2, "role_shown", true)

      return p1, p2
    end

    room:setPlayerProperty(lord, "role", "loyalist")
    room:setPlayerProperty(nonlord, "role_shown", true)
    room:broadcastProperty(nonlord, "role")

    local loyalist1, loyalist2 = summonFriends(lord)
    local rebel1, rebel2 = summonFriends(nonlord)

    local lord_generals = {}
    local nonlord_generals = {}
    local all_generals = room:getNGenerals(16)
    local first_selected, second_selected = {}, {}
    -- 用于储存双方已选择武将的序号（从0开始），不用字符串储存是考虑替换武将的情况

    local function chooseGeneral(p, n)
      local prompt = "#1v1_mode-choose:::"..(p == lord and "firstPlayer" or "secondPlayer")..":"..n
      local my_selected = (p == lord) and first_selected or second_selected
      local ur_selected = (p == lord) and second_selected or first_selected
      local my_genrals = (p == lord) and lord_generals or nonlord_generals
      local result = room:askToCustomDialog(p, {
        skill_name = "m_3v3_duel_mode",
        qml_path = "packages/gamemode/qml/1v1.qml",
        extra_data = {
          all_generals, n, my_selected, ur_selected, prompt
        }
      })
      local selected = {}
      if result ~= "" then
        ---@cast result any
        for i, id in ipairs(result.ids) do
          local g = result.generals[i]
          -- 更新武将替换
          all_generals[id+1] = g
          table.insert(my_selected, id)
          table.insert(my_genrals, g)
          table.insert(selected, g)
        end
      else
        local selected_list = table.connect(my_selected, ur_selected)
        for i, g in ipairs(all_generals) do
          if not table.contains(selected_list, i-1) then
            table.insert(my_selected, i-1)
            table.insert(my_genrals, g)
            table.insert(selected, g)
            if #selected == n then break end
          end
        end
      end
      room:sendLog{
        type = "#1v1ChooseGeneralsLog",
        arg = p == lord and "firstPlayer" or "secondPlayer",
        arg2 = selected[1],
        arg3 = selected[2] or "",
        toast = true,
      }
    end

    -- 1-2-2-2-2-2-2-2-1
    chooseGeneral(nonlord, 1)
    chooseGeneral(lord, 2)
    chooseGeneral(nonlord, 2)
    chooseGeneral(lord, 2)
    chooseGeneral(nonlord, 2)
    chooseGeneral(lord, 2)
    chooseGeneral(nonlord, 2)
    chooseGeneral(lord, 2)
    chooseGeneral(nonlord, 1)

    room:doBroadcastNotify("ShowToast", Fk:translate("3v3 duel choose general"))
    local req = Request:new({ lord, nonlord }, "AskForGeneral")
    req.timeout = self.room:getSettings('generalTimeout')
    req:setData(lord, { lord_generals, 3 })
    req:setData(nonlord, { nonlord_generals, 3 })
    req:setDefaultReply(lord, { lord_generals[1], lord_generals[2], lord_generals[3] })
    req:setDefaultReply(nonlord, { nonlord_generals[1], nonlord_generals[2], nonlord_generals[3] })
    req:ask()

    for _, p in ipairs { lord, nonlord } do
      local tab = p == lord and lord_generals or nonlord_generals
      local p1 = p == lord and loyalist1 or rebel1
      local p2 = p == lord and loyalist2 or rebel2
      local chosens = req:getResult(p)
      room:setPlayerGeneral(p, chosens[1], true, true)
      removeGeneral(tab, chosens[1])
      room:setPlayerGeneral(p1, chosens[2], true, true)
      removeGeneral(tab, chosens[2])
      room:setPlayerGeneral(p2, chosens[3], true, true)
      removeGeneral(tab, chosens[3])
    end

    room:askToChooseKingdom(room.players)
  end

  return m_3v3_duel_logic
end

local m_3v3_duel_mode = fk.CreateGameMode{
  name = "m_3v3_duel_mode",
  minPlayer = 2,
  maxPlayer = 2,
  rule = "#m_3v3_duel_rule&",
  logic = m_3v3_duel_getLogic,
  surrender_func = function(self, playedTime)
    return { { text = "time limitation: 2 min", passed = playedTime >= 120 } }
  end,
  winner_getter = function(self, victim)
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
    killer:drawCards(2, "game_rule")
  end,
}
Fk:loadTranslationTable{
  ["m_3v3_duel_mode"] = "统率三军（施工中）",
  ["3v3 duel choose general"] = "请选择3名武将，将按座位顺序分配给我方三名角色",

  [":m_3v3_duel_mode"] = desc_33,
}

return m_3v3_duel_mode
