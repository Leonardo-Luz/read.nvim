local floatwindow = require("floatwindow")
local fetch = require("http").fetch_html

local Path = require("plenary.path")

local M = {}

local state = {
  current_url = "",
  main_url = "",
  break_point = nil,
  chapter = 0,
  window_config = {
    main = {
      floating = {
        buf = -1,
        win = -1,
      },
    },
    header = {
      floating = {
        buf = -1,
        win = -1,
      },
    },
    footer = {
      floating = {
        buf = -1,
        win = -1,
      },
    },
  },
  data_file = Path:new(vim.fn.stdpath("data"), "read_data.json"),
}

-- INFO: START PERSISTENT DATA

local function read_data()
  if state.data_file:exists() then
    local file_content = state.data_file:read()
    return vim.json.decode(file_content)
  else
    return {}
  end
end

local function write_data(data)
  state.data_file:write(vim.json.encode(data), "w")
end

local function set_data(key, value)
  local data = read_data()
  data[key] = value
  write_data(data)
end

local function get_data(key)
  local data = read_data()

  return data[key]
end

-- INFO: END PERSISTENT DATA
--
-- INFO: START SCRAPE DATA

local scrape = function(url)
  local response = fetch(url)

  if response.err then
    vim.print(response.err)
    return
  end

  return response.response
end

local get_HTML = function(url)
  local html = scrape(url)

  if not html then
    return
  end

  local bodyStart = string.find(html, "<main[^>]*>")
  local bodyEnd = string.find(html, "</main>", bodyStart)

  if bodyStart and bodyEnd then
    local bodyContent = string.sub(html, bodyStart + string.len("<main"), bodyEnd)
    html = bodyContent
  else
    print("Error: <body> tags not found in HTML.")
    html = ""
  end

  local entity_map = {
    ["&#8221;"] = "”",
    ["&#8230;"] = "…",
    ["&#8220;"] = "“",
    ["&#8217;"] = "’",
    ["&#8216;"] = "‘",
    ["&#8211;"] = "–",
  }

  for entity, replacement in pairs(entity_map) do
    html = html:gsub(entity, replacement)
  end

  local pTags = {}

  for pTag in html:gmatch("<h1[^>]*>(.-)</h1>") do
    local cleanedText = pTag:gsub("<[^>]+>", "")

    cleanedText = cleanedText:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    table.insert(pTags, cleanedText)

    break
  end

  for pTag in html:gmatch("<p[^>]*>(.-)</p>") do
    local cleanedText = pTag:gsub("<[^>]+>", "")

    cleanedText = cleanedText:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    if cleanedText == state.break_point then
      goto continue
    end

    table.insert(pTags, cleanedText)
    table.insert(pTags, "")
  end
  ::continue::

  return pTags
end

-- INFO: END SCRAPE DATA
--
-- INFO: START WINDOW CONFIG

local foreach_float = function(callback)
  for name, float in pairs(state.window_config) do
    callback(name, float)
  end
end

local reading_progress = function()
  local pos = vim.api.nvim_win_get_cursor(state.window_config.main.floating.win)[1]
  local lines = #vim.api.nvim_buf_get_lines(state.window_config.main.floating.buf, 0, -1, false)

  local current_progress = (pos * 100) / lines

  local footer = "Progress "

  local progress_max_size = state.window_config.footer.opts.width - #footer

  vim.api.nvim_buf_set_lines(
    state.window_config.footer.floating.buf,
    0,
    -1,
    false,
    { footer .. ("#"):rep(math.floor((progress_max_size * current_progress) / 100)) }
  )
end

local window_config = function()
  local win_width = vim.api.nvim_win_get_width(0) -- Current window width
  local win_height = vim.api.nvim_win_get_height(0) -- Current window height

  local float_width = math.floor(win_width * 0.8)
  local float_height = math.floor(win_height * 0.6)

  local row = math.floor((win_height - float_height) / 2)
  local col = math.floor((win_width - float_width) / 2)

  return {
    main = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        width = float_width,
        height = float_height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
      },
      enter = true,
    },
    header = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        width = float_width,
        height = 1,
        col = col + 1,
        row = row - 1,
      },
      enter = false,
    },
    footer = {
      floating = {
        buf = -1,
        win = -1,
      },
      opts = {
        relative = "editor",
        style = "minimal",
        width = float_width,
        height = 1,
        col = col + 1,
        row = row + float_height + 2,
      },
      enter = false,
    },
  }
end

local set_content = function()
  state.current_url = string.format(state.main_url, state.chapter)

  local lines = get_HTML(state.current_url)

  if not lines then
    return
  end

  local title = table.remove(lines, 1)
  local padding = (" "):rep(math.floor((state.window_config.main.opts.width - #title) / 2))

  vim.api.nvim_buf_set_lines(state.window_config.header.floating.buf, 0, -1, false, { padding .. title })

  vim.api.nvim_buf_set_lines(state.window_config.main.floating.buf, 0, -1, false, lines)
end

local exit = function()
  local cursor_pos = vim.api.nvim_win_get_cursor(state.window_config.main.floating.win)

  local current_line = cursor_pos[1]
  set_data("current_pos", current_line)

  foreach_float(function(_, float)
    vim.api.nvim_win_close(float.floating.win, true)
  end)
end

local remaps = function()
  vim.keymap.set("n", "n", function()
    state.chapter = state.chapter + 1

    set_data("current_pos", 1)
    set_data("chapter", state.chapter)

    vim.api.nvim_win_set_cursor(state.window_config.main.floating.win, { 1, 1 })
    set_content()
  end, {
    buffer = state.window_config.main.floating.buf,
  })

  vim.keymap.set("n", "p", function()
    state.chapter = state.chapter - 1

    set_data("current_pos", 1)
    set_data("chapter", state.chapter)

    vim.api.nvim_win_set_cursor(state.window_config.main.floating.win, { 1, 1 })
    set_content()
  end, {
    buffer = state.window_config.main.floating.buf,
  })

  vim.keymap.set("n", "<ESC><ESC>", function()
    exit()
  end, {
    buffer = state.window_config.main.floating.buf,
  })

  vim.keymap.set("n", "q", function()
    exit()
  end, {
    buffer = state.window_config.main.floating.buf,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = state.window_config.main.floating.buf,
    callback = function()
      reading_progress()
    end,
  })
end

-- INFO: END WINDOW CONFIG

M.start = function()
  state.chapter = get_data("chapter") or state.chapter

  state.window_config = window_config()

  foreach_float(function(_, float)
    float.floating = floatwindow.create_floating_window(float)
  end)

  local current_pos = get_data("current_pos")

  remaps()

  set_content()

  vim.api.nvim_win_set_cursor(state.window_config.main.floating.win, { current_pos, 1 })
end

M.setup = function(opts)
  state.break_point = opts.break_point
  state.main_url = opts.url
  state.chapter = opts.chapter or 1
end

vim.api.nvim_create_user_command("Read", M.start, {})

return M
