local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local fn = n.fn
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local feed = n.feed

local function get_selected()
  exec_lua[[
  vim.cmd.clear()
  vim.cmd.mode()
  ]]
  return table.concat(fn.getregion(fn.getpos('v'), fn.getpos('.')), '\n')
end

local function set_lines(lines)
  if type(lines) == 'string' then
    lines = vim.split(lines, '\n')
  end
  api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function set_filetype(ft)
  api.nvim_set_option_value('filetype', ft, { buf = 0 })
end

local function treeselect(cmd_, ...)
  if cmd_ == 'select_node' then
    cmd_ = 'select_child'
  end

  exec_lua(function(cmd, ...)
    require 'vim.treesitter._select'[cmd](...)
  end, cmd_, ...)
end

for i=1,1 do
describe('treesitter incremental-selection '..i, function()
  before_each(function()
    clear()

    local code = {
      '',
      'foo(1)',
      'bar(2)',
      '',
    }

    set_lines(code)
    set_filetype('lua')
    feed('G')
  end)

  it('works', function()
    treeselect('select_node')
    eq('foo(1)\nbar(2)\n', get_selected())

    treeselect('select_child')
    eq('foo(1)', get_selected())

    treeselect('select_next')
    eq('bar(2)', get_selected())

    treeselect('select_prev')
    eq('foo(1)', get_selected())

    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
  end)

  it('repeat', function()
    for i=1,10000 do
    clear()

    local code = {
      '',
      'foo(1)',
      'bar(2)',
      '',
    }

    set_lines(code)
    set_filetype('lua')
    feed('G')

    set_lines('foo(1,2,3,4)')
    treeselect('select_node')
    eq('foo', get_selected())
    treeselect('select_next')
    eq('(1,2,3,4)', get_selected())
    treeselect('select_parent')
    eq('foo(1,2,3,4)', get_selected())

    treeselect('select_child', 2)
    eq('1', get_selected())

    treeselect('select_next', 3)
    eq('4', get_selected())

    exec_lua'_G.T=true'
    treeselect('select_prev', 2)
    eq('2', get_selected())
    exec_lua'_G.T=false'

    treeselect('select_parent', 2)
    eq('foo(1,2,3,4)', get_selected())

    treeselect('select_child', 2)
    eq('2', get_selected())
    end
  end)

  it('history', function()
    treeselect('select_node')
    treeselect('select_child')
    treeselect('select_next')

    eq('bar(2)', get_selected())
    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
    treeselect('select_child')
    eq('bar(2)', get_selected())

    treeselect('select_prev')

    eq('foo(1)', get_selected())
    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
    treeselect('select_child')
    eq('foo(1)', get_selected())
  end)

  it('selects node as parent when node half-selected', function()
    feed('kkl', 'v', 'l')
    eq('oo', get_selected())

    treeselect('select_parent')
    eq('foo', get_selected())
  end)

  it('selects node as child when node half-selected', function()
    feed('kkl', 'v', 'l')
    eq('oo', get_selected())

    treeselect('select_child')
    eq('foo', get_selected())
  end)

  it('finds child node when node half-selected', function()
    feed('kkl', 'v', 'j')
    eq('oo(1)\nba', get_selected())

    treeselect('select_child')
    eq('(1)', get_selected())
  end)

  it('maintains cursor selection-end-pos', function()
    feed('kk')
    treeselect('select_node')
    eq('foo', get_selected())

    treeselect('select_parent')
    feed('h')
    eq('foo(1', get_selected())

    treeselect('select_child')
    eq('foo', get_selected())

    feed('o')
    treeselect('select_parent')
    feed('l')
    eq('oo(1)', get_selected())
  end)

  it('handles outside root node', function()
    feed('gg', 'v')
    eq('', get_selected())

    treeselect('select_node')
    eq('foo(1)\nbar(2)\n', get_selected())

    feed('<esc>gg', 'v')
    eq('', get_selected())

    treeselect('select_child')
    eq('foo(1)\nbar(2)\n', get_selected())

    feed('<esc>gg', 'v')
    eq('', get_selected())

    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
  end)
end)
end
