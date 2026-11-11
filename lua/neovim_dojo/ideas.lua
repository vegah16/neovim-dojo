local M = {}

local function markdown(idea)
  local lines = {
    "",
    "## " .. idea.title,
    "",
    "- Status: idea",
    "- Created: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
  local task = idea.task or idea.lesson
  if task then
    lines[#lines + 1] = "- Context task: `" .. task .. "`"
  end
  if idea.query and idea.query ~= "" then
    lines[#lines + 1] = "- Search: `" .. idea.query .. "`"
  end
  if idea.facets and next(idea.facets) then
    local facets = {}
    for key, value in pairs(idea.facets) do
      facets[#facets + 1] = key .. ":" .. value
    end
    table.sort(facets)
    lines[#lines + 1] = "- Facets: `" .. table.concat(facets, "`, `") .. "`"
  end
  if idea.note and idea.note ~= "" then
    vim.list_extend(lines, { "", idea.note })
  end
  return lines
end

function M.add(path, idea)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if vim.fn.filereadable(path) ~= 1 then
    if vim.fn.writefile({ "# Neovim Dojo task ideas", "", "Backlog for future curriculum work." }, path) ~= 0 then
      return false
    end
  end
  return vim.fn.writefile(markdown(idea), path, "a") == 0
end

return M
