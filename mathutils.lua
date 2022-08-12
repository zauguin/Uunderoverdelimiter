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

local letter = token.command_id'letter'
local other = token.command_id'other'
local char_given = token.command_id'char_given'
local char_num = token.command_id'char_num'
local math_char_num = token.command_id'math_char_num'
local math_given = token.command_id'math_given'
local xmath_given = token.command_id'xmath_given'
local delim_num = token.command_id'delim_num'

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
    do
      local new_tail = noad.prev
      this_nest.tail, new_tail.next = new_tail, nil
    end

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
    local class, family, cp
    if cmd == letter or cmd == other or cmd == char_given or cmd == char_num then
      local code = cmd == char_num and token.scan_int() or t.index
      class, family, cp = tex.getmathcodes(code)
      if class == 8 then
        token.put_next(token.create(utf8.char(0xFFFF, code)))
        return scan_math(style_mapping)
      end
    elseif cmd == math_char_num then
      local value = token.scan_int()
      if t.index == 0 and value > 0x8000 or t.index == 2 then
        class = (value >> 21) & 0x7
        family = (value >> 24) & 0xFF
        cp = value & 0x1FFFFF
      elseif t.index == 0 then
        assert(value >= 0)
        class = (value >> 12) & 0xF
        family = (value >> 8) & 0xF
        cp = value & 0xFF
      elseif t.index == 1 then
        class = value
        family = token.scan_int()
        cp = token.scan_int()
      else
        assert(false)
      end
    elseif cmd == math_given then
      class = (t.index >> 12) & 0xF
      family = (t.index >> 8) & 0xF
      cp = t.index & 0xFF
    elseif cmd == xmath_given then
      class = (t.index >> 21) & 0x7
      family = (t.index >> 24) & 0xFF
      cp = t.index & 0x1FFFFF
    elseif cmd == delim_num then
      if t.index == 0 then
        local value = token.scan_int()
        class = (value >> 24) & 0xF
        family = (value >> 20) & 0xF
        cp = (value >> 12) & 0xFF
      elseif t.index == 1 then
        class = token.scan_int()
        family = token.scan_int()
        cp = token.scan_int()
      else
        assert(false)
      end
    else
      tex.error"A { was required here"
      class, family, cp = 0, 0, 0
    end
    local char = node.new'math_char'
    char.fam = class == 7 and tex.fam >= 0 and tex.fam < 0x100 and tex.fam or family
    char.char = cp
    return char
  end
end

local function sub_style(s) return 2*(s//4) + 5 end
local function sup_style(s) return 2*(s//4) + 4 + s%2 end
local function num_style(s) return s + 2 - 2*(s//6) end
local function denom_style(s) return (s + 2 - 2*(s//6)) | 1 end
local function cramped_style(s) return s | 1 end

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
  num_style = num_style,
  denom_style = denom_style,
  cramped_style = cramped_style,
  style_mapping = style_mapping,
}
