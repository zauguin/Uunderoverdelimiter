local mathutils = require'mathutils'
local style_mapping = mathutils.style_mapping
local sub_style = mathutils.sub_style
local sup_style = mathutils.sup_style

local math_char = node.id'math_char'
local style_id = node.id'style'
assert(style_id)

local radical_degree_style = {
  [2] = function() return 6 end,
  [7] = sub_style, -- Extension
}

local radical_nucleus_style = {
  [0] = cramped_style,
        cramped_style,
        cramped_style,
        sub_style,
        sup_style,
        nil,
        cramped_style,
        nil,
        sup_style, -- Extension
}

local function visit_list(head, visitor, style, penalties)
  local current = head
  local prev
  while current do
    local next = current.next
    local mapped, keep_node_link = visitor(current, style, penalties)
    if mapped ~= false and (mapped == true and current or mapped).id == style_id then
      style = mapped.subtype
    end
    if mapped == true then -- The fast path. Implicitly keep_node_link == true and you better didn't change anything earlier
      if current.id == style_id then
        style = current.subtype
      end
      prev, current = current, current.next
    elseif keep_node_link then -- For very special uses which have to mess with the list. Let's hope that the user knows what they are doing.
      if mapped == nil then
        if current == head then
          return nil
        else
          return head
        end
      else
        if mapped.id == style_id then
          style = mapped.subtype
        end
        prev = mapped
        current = mapped.next
        if mapped.prev == nil then
          head = mapped
        end
      end
    elseif mapped == nil then
      if not prev then
        head = next
      end
      current = next
    else -- Replace just one node with a potential list
      mapped.prev = prev
      if prev then
        prev.next = mapped
      else
        head = mapped
      end
      for n, s in node.traverse_id(style_id, mapped) do
        mapped, style = n, s
      end
      mapped = node.tail(mapped)
      if next then
        mapped.next = next
        next.prev = mapped
      end
      current = next
    end
  end
  return head
end

local function kernel_visitor(base, field, style_transform, visitor, style, penalties)
  local kernel = base[field]
  if not kernel then return end
  style = style_transform and style_transform(style) or style
  local mapped = visitor(kernel, style, penalties)
  if mapped ~= true then
    base[field] = mapped
  end
end

local function nss_visitor(n, visitor, style, penalties)
  kernel_visitor(n, 'nucleus', nil, visitor, style, false)
  kernel_visitor(n, 'sub', sub_style, visitor, style, false)
  kernel_visitor(n, 'sup', sup_style, visitor, style, false)
end

local children_visitor = setmetatable({
  [node.id'noad'] = nss_visitor,
  [node.id'choice'] = function(n, visitor, style, penalties)
    local simple_style = style // 2
    local field = simple_style == 0 and 'display' or simple_style == 1 and 'text' or simple_style == 2 and 'script' or 'scriptscript'
    n[field] = visit_list(n[field], visitor, style, penalties)
  end,
  [node.id'radical'] = function(n, visitor, style, penalties)
    local sub = n.subtype
    local degree_style = radical_degree_style[sub]
    kernel_visitor(n, 'degree', degree_style, visitor, style, false)
    kernel_visitor(n, 'left', nil, visitor, style, false)
    local nucleus_style = radical_nucleus_style[sub]
    kernel_visitor(n, 'nucleus', nucleus_style, visitor, style, false)
    kernel_visitor(n, 'sub', sub_style, visitor, style, false)
    kernel_visitor(n, 'sup', sup_style, visitor, style, false)
  end,

  [node.id'sub_mlist'] = function(n, visitor, style, penalties)
    n.list = visit_list(n.list, visitor, style, penalties)
  end,
  [node.id'math_char'] = false,
  [node.id'sub_box'] = false,
  [node.id'delim'] = false,
}, {
  __index = function(t, i)
    print('Warning: Unhandled type ', node.type(i))
    t[i] = false
    return false
  end
})

return function(mappings)
  local function visitor(n, style, penalties)
    local id = n.id
    local visit = children_visitor[id]
    if visit then
      visit(n, visitor, style, penalties)
    end
    visit = mappings[id]
    if visit then
      return visit(n, style, penalties)
    else
      return true
    end
  end
  return function(head, style, penalties)
    if type(style) == 'string' then
      style = style_mapping[style]
    end
    return visit_list(head, visitor, style, penalties)
  end
end

--[[
return {
  mmode = mmode,
  scan_math = scan_math,
  sub_style = sub_style,
  sup_style = sup_style,
  style_mapping = style_mapping,
}
]]
