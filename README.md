# NoteFloat.nvim

A simple Neovim plugin that provides a floating, persistent note-taking window that saves automatically between sessions.

## Features

- **Persistent Notes** - Notes are saved automatically and persist between Neovim sessions
- **Multiple Categories** - Create different note categories for different purposes (quick notes, TODOs, meeting notes, etc.)
- **Floating UI** - Clean, non-intrusive floating window with customizable size and border
- **Markdown Support** - Notes are saved as markdown files by default
- **Auto-save** - Notes save automatically as you type (with customizable debounce)
- **Lightweight** - Simple implementation with minimal dependencies
- **Fast** - No performance impact on your editor

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "deveshidwivedi/notefloat.nvim",
  config = function()
    require("notefloat").setup()
  end
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "deveshidwivedi/notefloat.nvim",
  config = function()
    require("notefloat").setup()
  end
}
```

### With [mini.deps](https://github.com/echasnovski/mini.deps)

```lua
later(function()
  add("deveshidwivedi/notefloat.nvim")
  require("notefloat").setup()
end)
```

## Usage

### Basic Usage

1. Toggle the notes window:

   ```
   :NoteFloat
   ```

2. Open a specific note category:

   ```
   :NoteFloat todo
   ```

3. List and select from available categories:
   ```
   :NoteFloatList
   ```

### Recommended Keymaps

Add these to your config:

```lua
-- Toggle default quick notes
vim.keymap.set('n', '<Leader>nn', '<cmd>NoteFloat<CR>', { desc = 'Toggle quick notes' })

-- Toggle TODO list
vim.keymap.set('n', '<Leader>nt', '<cmd>NoteFloat todo<CR>', { desc = 'Toggle TODO notes' })

-- Toggle meeting notes
vim.keymap.set('n', '<Leader>nm', '<cmd>NoteFloat meeting<CR>', { desc = 'Toggle meeting notes' })

-- Toggle code snippets
vim.keymap.set('n', '<Leader>nc', '<cmd>NoteFloat code<CR>', { desc = 'Toggle code snippets' })

-- Open category selector
vim.keymap.set('n', '<Leader>nl', '<cmd>NoteFloatList<CR>', { desc = 'List note categories' })
```

## Configuration

You can customize NoteFloat by passing options to the setup function:

```lua
require("notefloat").setup({
  -- Size of the floating window (0.0 to 1.0)
  size = 0.6,

  -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
  border = "rounded",

  -- Default filetype for notes
  filetype = "markdown",

  -- Auto-save notes when they change
  auto_save = true,

  -- Debounce time for auto-save in milliseconds
  debounce_ms = 1000,

  -- Available note categories
  categories = {"quick", "todo", "code", "meeting", "project"}
})
```

## Storage

Notes are saved in your Neovim data directory:

- Linux: `~/.local/share/nvim/notefloat/`
- macOS: `~/Library/Application Support/nvim/notefloat/`
- Windows: `%LOCALAPPDATA%\nvim-data\notefloat\`

Each note category is saved as a separate markdown file.

## Why NoteFloat?

Many developers keep scratch files or temporary notes open while working. NoteFloat makes this process seamless:

- No need to create and manage temporary files
- Notes persist between sessions and are always accessible with a keystroke
- Different note categories help organize different types of content
- The floating window doesn't disrupt your window layout or workflow

## Requirements

- Neovim >= 0.7.0
- For the title feature: Neovim >= 0.9.0 (optional)
