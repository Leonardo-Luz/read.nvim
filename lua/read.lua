local floatwindow = require("floatwindow")
local fetch = require("http").fetch_html

local Path = require("plenary.path")

local M = {}

local state = {
  current_url = "",
  main_url = "",
  break_point = nil,
  chapter = 0,
  replacement = nil,
  style = nil,
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
  cmdheight = {
    original = vim.o.cmdheight,
    removed = 0,
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

  data[tostring(data["current_id"])][key] = value
  write_data(data)
end

-- INFO:
-- local function set_array()
--   if data[key] == nil then
--     data["current_id"] = #data
--   end
--   data[#data][key] = value
-- end

local function get_data(key)
  local data = read_data()

  if data["current_id"] and data["current_id"] > 0 then
    return data[tostring(data["current_id"])][key]
  end

  return nil
end

local function get_total()
  local data = read_data()

  if data["current_id"] then
    table.remove(data, 1)
  end

  return data
end

local function new_data(book)
  local data = read_data()

  data["count"] = (data["count"] or 0) + 1
  data["current_id"] = data["count"]
  data[tostring(data["count"])] = book

  vim.print(data)

  write_data(data)
end

local function delete_data(id)
  local data = read_data()

  data[tostring(id)] = nil

  write_data(data)
end

local function set_id(id)
  local data = read_data()

  data["current_id"] = id

  write_data(data)
end

-- INFO: END PERSISTENT DATA
--
-- INFO: START SCRAPE AND FORMAT DATA

local scrape = function(url)
  local response = fetch(url, {})

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
    print("Error: <main> tags not found in HTML.")
    html = ""
  end

  if state.replacement then
    for entity, replacement in pairs(state.replacement) do
      html = html:gsub(entity, replacement)
    end
  end

  local pTags = {}

  for pTag in html:gmatch("<p[^>]*>(.-)</p>") do
    local cleanedText = pTag:gsub("<[^>]+>", "")

    cleanedText = " " .. cleanedText:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    if cleanedText == " " .. state.break_point then
      goto continue
    end

    if cleanedText:len() > 0 then
      table.insert(pTags, cleanedText)
    end

    table.insert(pTags, "")
  end
  ::continue::

  return pTags
end

-- INFO: END SCRAPE AND FORMAT DATA
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

  local footer_start = " Progress "
  local footer_end = string.format(" %d%% ", current_progress)

  local progress_max_size = state.window_config.footer.opts.width
      - #footer_start
      - #footer_end
      - ((state.style == "float" and 0) or 2)

  local parsed_progras_percent = math.floor((progress_max_size * current_progress) / 100)

  vim.api.nvim_buf_set_lines(state.window_config.footer.floating.buf, 0, -1, false, {
    footer_start
    .. ("#"):rep(parsed_progras_percent)
    .. ("-"):rep(progress_max_size - parsed_progras_percent)
    .. footer_end,
  })
end

local window_config = function()
  local win_width = vim.api.nvim_win_get_width(0)   -- Current window width
  local win_height = vim.api.nvim_win_get_height(0) -- Current window height

  local float_width = win_width
  local float_height = win_height - 4

  local row = 3
  local col = 1

  if state.style == "float" then
    float_width = math.floor(win_width * 0.8)
    float_height = math.floor(win_height * 0.6)

    row = math.floor((win_height - float_height) / 2)
    col = math.floor((win_width - float_width) / 2)
  end

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
        border = (state.style == "float" and "rounded") or "none",
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
        col = col + 0,
        row = row - ((state.style == "float" and 1) or 4),
        border = (state.style == "float" and { " ", "", " ", " ", " ", " ", " ", " " })
            or { " ", " ", " ", " ", " ", " ", " ", " " },
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
        col = col + ((state.style == "float" and 0) or 0),
        row = row + float_height + ((state.style == "float" and 2) or 0),
        border = (state.style == "float" and { " ", "", " ", " ", " ", "", " ", " " })
            or { " ", " ", " ", " ", " ", " ", " ", " " },
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

  local title = get_data("title") .. " - " .. state.chapter
  local padding = (" "):rep(math.floor((state.window_config.main.opts.width - #title) / 2))

  vim.api.nvim_buf_set_lines(state.window_config.header.floating.buf, 0, -1, false, { padding .. title })

  vim.api.nvim_buf_set_lines(state.window_config.main.floating.buf, 0, -1, false, lines)
end

local exit = function()
  local cursor_pos = vim.api.nvim_win_get_cursor(state.window_config.main.floating.win)

  local current_line = cursor_pos[1]
  set_data("current_pos", current_line)

  if state.style == "minimal" then
    vim.opt.cmdheight = state.cmdheight.original
  end

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

local create_prompt = function(title, callback)
  -- Get current window size
  -- local width = vim.api.nvim_win_get_width(0) -- Current window width
  -- local height = vim.api.nvim_win_get_height(0) -- Current window height

  local width = vim.o.columns
  local height = vim.o.lines

  local config = {
    header = {},
    prompt = {},
  }

  -- Set up the floating window options
  config.header = {
    floating = {
      buf = -1,
      win = -1,
    },
    opts = {
      relative = "editor",
      width = string.len(title),                                                  -- Set the width of the window to 50% of the screen
      height = 1,
      col = math.floor((width * 0.5) / 2) + math.floor((width - #title) * 0.2),   -- Center the window horizontally
      row = math.floor((height * 0.5)) - 0,                                       -- Center the window vertically
      style = "minimal",
      zindex = 3,
      border = { " ", " ", " ", " ", " ", "", " ", " " },
    },
    enter = false,
  }

  config.prompt = {
    floating = {
      buf = -1,
      win = -1,
    },
    opts = {
      relative = "editor",
      width = math.floor(width * 0.4),         -- Set the width of the window to 50% of the screen
      height = 1,
      col = math.floor((width * 0.5) / 2) + 3, -- Center the window horizontally
      row = math.floor((height * 0.5)) + 1,    -- Center the window vertically
      style = "minimal",
      border = "rounded",
      zindex = 2,
    },
    enter = true,
  }

  for _, float in pairs(config) do
    float.floating = floatwindow.create_floating_window(float)
  end

  vim.api.nvim_buf_set_lines(config.header.floating.buf, 0, -1, false, { title })

  vim.keymap.set({ "n", "i" }, "<CR>", callback, {
    buffer = config.prompt.floating.buf,
  })

  local exit_prompt = function()
    for _, float in pairs(config) do
      pcall(vim.api.nvim_win_close, float.floating.win, true)
    end
  end

  vim.keymap.set("n", "q", function()
    exit_prompt()
  end, {
    buffer = config.prompt.floating.buf,
  })
  vim.keymap.set("n", "<esc><esc>", function()
    exit_prompt()
  end, {
    buffer = config.prompt.floating.buf,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = config.prompt.floating.buf,
    callback = function()
      exit_prompt()
    end,
  })

  return config.prompt.floating
end

M.new_book = function()
  local book = {
    url = nil,
    title = nil,
    break_point = nil,
    chapter = 0,
    current_pos = 1,
  }

  create_prompt("URL", function()
    local url = string.gsub(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1], "%s", "")
    book.url = url

    create_prompt("Title", function()
      book.title = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]

      create_prompt("Optional: Break Point", function()
        local break_point = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
        book.break_point = (#break_point > 0 and break_point) or nil

        create_prompt("Optional: Chapter", function()
          local chapter = tonumber(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1])
          book.chapter = chapter

          pcall(vim.api.nvim_win_close, 0, true)

          if book.url and book.title then
            new_data(book)
            M.start()
            return
          end

          vim.print("Error creating a new book")
        end)
      end)
    end)
  end)
end

M.start = function()
  state.chapter = get_data("chapter")
  state.main_url = get_data("url")
  state.break_point = get_data("break_point")

  if not state.current_url then
    M.new_book()
    return
  end

  state.window_config = window_config()

  foreach_float(function(_, float)
    float.floating = floatwindow.create_floating_window(float)
  end)

  local current_pos = get_data("current_pos") or 1

  remaps()

  set_content()

  if state.style == "minimal" then
    vim.opt.cmdheight = state.cmdheight.removed
  end

  vim.api.nvim_win_set_cursor(state.window_config.main.floating.win, { current_pos, 1 })
end

M.menu = function()
  local data = get_total()

  local choices = {}

  if data then
    for key, choice in pairs(data) do
      if type(choice) == "number" then
        goto continue
      end

      table.insert(choices, key .. " - Chapter: " .. choice.chapter .. ", Title: " .. choice.title)

      ::continue::
    end
  end

  table.insert(choices, "+ New Book")

  vim.ui.select(choices, {
    prompt = "Books",
  }, function(choice)
    if choice == nil then
      return
    end

    if choice == "+ New Book" then
      M.new_book()
      return
    end

    local striped_id = choice:match("(%d+)")

    set_id(tonumber(striped_id))
    M.start()
  end)
end

M.delete_menu = function()
  local data = get_total()

  local choices = {}

  if data then
    for key, choice in pairs(data) do
      if type(choice) == "number" then
        goto continue
      end

      table.insert(choices, key .. " - Chapter: " .. choice.chapter .. ", Title: " .. choice.title)

      ::continue::
    end
  end

  table.insert(choices, "- Cancel")

  vim.ui.select(choices, {
    prompt = "Delete Books",
  }, function(choice)
    if choice == nil or choice == "- Cancel" then
      return
    end

    vim.ui.select({ "Yes", "No" }, {
      prompt = "Do you realy want to delete the book " .. choice,
    }, function(response)
      if response == "Yes" then
        local striped_id = choice:match("(%d+)")

        delete_data(tonumber(striped_id))
      end
    end)
  end)
end

---comment
---@param opts { break_point: string|nil, url:string, chapter:number|nil, replacement: table|nil, style:'minimal'|'float'|nil }
M.setup = function(opts)
  state.break_point = opts.break_point
  state.main_url = opts.url
  state.chapter = opts.chapter or 1
  state.replacement = opts.replacement
  state.style = opts.style
end

vim.api.nvim_create_user_command("Read", M.start, {})
vim.api.nvim_create_user_command("ReadNew", M.new_book, {})
vim.api.nvim_create_user_command("ReadMenu", M.menu, {})
vim.api.nvim_create_user_command("ReadDeleteMenu", M.delete_menu, {})
vim.api.nvim_create_user_command("ReadData", function()
  local data = read_data()
  vim.print(data)
end, {})

return M
