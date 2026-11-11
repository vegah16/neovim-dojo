local M = {}

function M.default_random(first, last)
  return first + (vim.fn.rand() % (last - first + 1))
end

function M.shuffle(values, random)
  random = random or M.default_random
  local result = vim.deepcopy(values)
  for index = #result, 2, -1 do
    local other = random(1, index)
    result[index], result[other] = result[other], result[index]
  end
  return result
end

function M.sample(values, count, random)
  assert(#values > 0, "cannot sample an empty drill fixture pool")
  assert(count >= 0 and count % 1 == 0, "drill fixture sample count must be a non-negative integer")
  random = random or M.default_random

  local result = {}
  while #result < count do
    for _, value in ipairs(M.shuffle(values, random)) do
      if #result == count then
        break
      end
      result[#result + 1] = vim.deepcopy(value)
    end
  end
  return result
end

function M.schedule(values, count, random)
  assert(#values > 0, "cannot schedule an empty drill fixture pool")
  assert(count >= 0 and count % 1 == 0, "drill fixture schedule count must be a non-negative integer")

  local result = {}
  while #result < count do
    for _, value in ipairs(values) do
      if #result == count then
        break
      end
      result[#result + 1] = vim.deepcopy(value)
    end
  end
  return M.shuffle(result, random)
end

return M
