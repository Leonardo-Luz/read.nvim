## read.nvim

*A Neovim Plugin for Reading Web Pages*

* `read.nvim` is a Neovim plugin that simplifies reading online text by scraping content from a specified URLs.  It offers features to manage your reading progress across chapters and creating multiple reading sessions.

**Features:**

* Scrapes text from `<p>` tags inside the `<main>` tag from a URL.
* Saves your current reading position within a chapter.
* Saves the chapter you last read.
* Add multiple reading sessions.

**Dependencies:**

* `leonardo-luz/floatwindow.nvim`
* `leonardo-luz/http.nvim`
* `nvim-lua/plenary.nvim`

**Installation:**

Add `leonardo-luz/read.nvim` to your Neovim plugin manager (e.g., in your `init.lua` or `plugins/read.lua`).

Configure it with your desired URL and initial chapter:

```lua
{
  'leonardo-luz/read.nvim',
  opts = {
    style = "minimal",  -- Optional: minimal|nil makes the text fullscreen, while float makes a float window for the text
    replacement = {
        ['&#8221;'] = '”', -- example
        ['&#8220;'] = '“', -- example
    }  -- Optional: A table to replace specific HTML entities with other characters (default is nil)
  }
}
```


**Usage:**

* `:Read`: Resumes reading from the last accessed URL.
* `:ReadNew`: Creates a new reading session, prompting for the URL and title.  You can optionally specify the starting chapter and a breakpoint within the HTML.
* `:ReadMenu`: Displays a list of all your currently active reading sessions.
* `:ReadDeleteMenu`: Deletes a specific reading session.
* `n`: Proceeds to the next chapter.
* `p`: Returns to the previous chapter.
* `q` or `<Esc><Esc>`: Closes the reader.

**Creating a New Reading Session:**

When creating a new reading session you'll be prompted for:

* **URL:** The website address to read.
* **Title:** A descriptive title for your reading session.
* **(Optional) Chapter:** The starting chapter number. (default 1)
* **(Optional) Breakpoint:** A specific point within the HTML to end.
