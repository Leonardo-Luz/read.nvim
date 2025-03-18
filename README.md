## read.nvim

*A Neovim Plugin for Reading Web Pages*

* `read.nvim` is a Neovim plugin that simplifies reading online text by scraping content from a specified URL.  It offers features to manage your reading progress across chapters.

**Features:**

* Scrapes text from `<p>` tags inside the `<main>` tag from a URL.
* Saves your current reading position within a chapter.
* Saves the chapter you last read.

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
    url = 'https://your.preferred.site/chapter_%d', -- Required: Your target URL. Replace the chapter number with %d, e.g., "example://example_book_chapter_123.com" should be "example://example_book_chapter_%d.com"
    chapter = 1,  -- Optional: The starting chapter (default is 1)
    break_point = nil,  -- Optional: A string indicating the end of a chapter (default is nil)
    style = "minimal",  -- Optional: minimal|nil makes the text fullscreen, while float makes a float window for the text
    replacement = {
        ['&#8221;'] = '”', -- example
        ['&#8220;'] = '“', -- example
    }  -- Optional: A table to replace specific HTML entities with other characters (default is nil)
  }
}
```

**Usage:**

* `:Read`: Begins reading from the specified URL and chapter.
* `n`: Proceeds to the next chapter.
* `p`: Returns to the previous chapter.
* `q` or `<Esc><Esc>`: Quits the reader.
