local nest = tex.nest

local mmode do
  local modes = tex.getmodevalues()
  for mode, name in pairs(modes) do
    if name == 'math' then mmode = mode break end
  end
  assert(mmode)
end

local left_brace = token.command_id'left_brace'
local spacer = token.command_id'spacer'
local relax = token.command_id'relax'

local after_group = token.new(0, token.command_id'after_group')

-- Complicated...
local function scan_math(style_mapping)
  local this_nest = nest.top
  local mode = this_nest.mode
  if mode ~= mmode and mode ~= -mmode then
    tex.error'math mode required'
    return
  end
  local t = token.scan_token()
  local cmd = t.command

  while cmd == spacer or cmd == relax do
    t = token.scan_token()
    cmd = t.command
  end

  if cmd == left_brace then
    tex.runtoks(function()
      this_nest.mode = mode
      token.put_next(t)
    end)
    local noad = this_nest.tail
    this_nest.tail = noad.prev
    local kernel = noad.nucleus
    noad.nucleus = nil
    node.free(noad)
    local inner_nest = nest.top
    if style_mapping then
      inner_nest.mathstyle = style_mapping(inner_nest.mathstyle)
    end
    tex.runtoks(function()
      inner_nest.mode = -mmode
      token.put_next(after_group)
    end)
    return kernel
  else
    -- skip the other cases for now
    error'TODO'
  end
end

local function sub_style(s) return 2*(s//4) + 5 end
local function sup_style(s) return 2*(s//4) + 4 + s%2 end

local style_mapping = {
  [0] = 'display',
        'crampeddisplay',
        'text',
        'crampedtext',
        'script',
        'crampedscript',
        'scriptscript',
        'crampedscriptscript',
}

for i=0,7 do
  style_mapping[style_mapping[i]] = i
end

local function check_math()
  -- TODO
  return true
end

return {
  check_math = check_math,
  mmode = mmode,
  scan_math = scan_math,
  sub_style = sub_style,
  sup_style = sup_style,
  style_mapping = style_mapping,
}