local skill = fk.CreateSkill {
  name = "#night_cloth_skill",
  tags = { Skill.Compulsory },
  attached_equip = "night_cloth",
}

Fk:loadTranslationTable{
  ["#night_cloth_skill"] = "夜行衣",
}

skill:addEffect(fk.PreCardEffect, {
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(skill.name) and
    data.card.type == Card.TypeTrick and data.card.color == Card.Black
  end,
  on_use = function (self, event, target, player, data)
    data.nullified = true
  end,
})

return skill
