local mathutils = require'mathutils'
local mathmap = require'mathmap'

local uunderoverdelimiter = 8 -- a new radical subtype

local func = luatexbase.new_luafunction'Uunderoverdelimiter'
token.set_lua('Uunderoverdelimiter', func, 'protected')
lua.get_functions_table()[func] = function(func)
  if not mathutils.check_math(func) then return end

  local n = node.new('radical')
  local delim = node.new('delim')

  n.subtype = uunderoverdelimiter
  n.left = delim
  delim.small_fam = token.scan_int()
  delim.small_char = token.scan_int()

  node.write(n)

  n.degree = mathutils.scan_math(mathutils.sub_style)
  n.nucleus = mathutils.scan_math(mathutils.sup_style)
end

local function clean_box(kernel, style)
  if not kernel then
    local list = node.new'hlist'
    list.dir = tex.textdir
    return list
  end
  local list
  local id = kernel.id
  if id == node.id'sub_box' then
    list = kernel.list
    kernel.list = nil
  else
    if id == node.id'sub_mlist' then
      list = kernel.list
      kernel.list = nil
    elseif id == node.id'math_char' then
      list = node.new'noad'
      list.nucleus = node.copy(kernel)
    end
    list = list and node.mlist_to_hlist(list, mathutils.style_mapping[style], false) or node.new'hlist'
  end
  if list.id > 1 or list.next or list.shift ~= 0 then
    list = node.hpack(list)
    list.attr = list.head.attr
  end
  node.free(kernel)
  return list
end

local my_mathmap = mathmap{
  [node.id'radical'] = function(n, style, penalties)
    local sub = n.subtype
    if sub ~= uunderoverdelimiter then
      return true
    end
    local new_noad = node.new'noad'
    new_noad.attr = n.attr
    new_noad.sub = n.sub
    new_noad.sup = n.sup
    n.sub, n.sup, n.next, n.prev = nil
    local under = clean_box(n.degree, mathutils.sub_style(style))
    local over = clean_box(n.nucleus, mathutils.sup_style(style))
    n.degree, n.nucleus = nil, node.new'sub_box'
    n.subtype = 7 -- \Uhextensible
    n.width = under.width < over.width and over.width or under.width
    local kernel = node.new'sub_mlist'
    kernel.list = n
    local delim = clean_box(kernel, style)
    -- ATTENTION: n no longer exists here

    local stylename = mathutils.style_mapping[style]
    local over_bgap = tex.getmath('overdelimiterbgap', stylename)
    local over_vgap = tex.getmath('overdelimitervgap', stylename)
    local under_bgap = tex.getmath('underdelimiterbgap', stylename)
    local under_vgap = tex.getmath('underdelimitervgap', stylename)

    local min_over_vgap = over_bgap - over.depth - delim.height
    local min_under_vgap = under_bgap - under.height - delim.depth
    if over_vgap < min_over_vgap then over_vgap = min_over_vgap end
    if under_vgap < min_under_vgap then under_vgap = min_under_vgap end
    local kern = node.new'kern'
    kern.kern = over_vgap
    over.next = kern
    kern.next = delim
    kern = node.new'kern'
    kern.kern = under_vgap
    delim.next = kern
    kern.next = under

    local list = node.vpack(over)
    list.direction = tex.textdirection
    list.height = delim.height + over_vgap + over.height + over.depth
    list.depth = delim.depth + under_vgap + under.height + under.depth
    local w = list.width
    for n in node.traverse_list(over) do
      if n.width < w then
        n.shift = (w - n.width)//2
      end
    end


    kernel = node.new'sub_box'
    kernel.list = list
    new_noad.nucleus = kernel
    return new_noad
  end,
}

luatexbase.add_to_callback('pre_mlist_to_hlist_filter', function(head, style, penalties)
  return my_mathmap(head, style, penalties)
end, 'Uunderoverdelimiter')
