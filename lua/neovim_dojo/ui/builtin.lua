local M = {}

function M.open(core)
  local lessons = vim.tbl_filter(function(lesson)
    return core.availability(lesson)
  end, core.lessons())
  vim.ui.select(lessons, {
    prompt = "Neovim Dojo task",
    format_item = function(lesson)
      local item = core.lesson_state(lesson)
      local marker = item.review == "issue" and "!"
        or item.review == "changed" and "↻"
        or item.review ~= "verified" and "○"
        or item.completed and "✓"
        or "◇"
      return ("%s %s · %s"):format(marker, lesson.title, table.concat(lesson.topics, ", "))
    end,
  }, function(lesson)
    if lesson then
      core.start(lesson.id)
    end
  end)
end

return M
