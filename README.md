# NoteFloat.nvim

A sophisticated Neovim plugin that provides floating, persistent note-taking with auto-sync capabilities, multi-window management, and AI-powered note summarization.

## Features

- **Persistent Notes** - Notes are saved automatically and persist between Neovim sessions
- **Multiple Categories** - Create different note categories for different purposes (quick notes, TODOs, meeting notes, etc.)
- **Floating UI** - Clean, non-intrusive floating window with customizable size and border
- **Auto-save** - Notes save automatically as you type with debounce
- **Periodic Save** - Additional periodic saving to prevent data loss during crashes
- **Git Sync** - Automatically commit and push your notes to a Git repository
- **Note Summarization** - Get AI-powered summaries of your notes (requires OpenAI CLI)
- **Multi-window Management** - Sidebar to manage and navigate between different note categories
- **Markdown Support** - Notes are saved as markdown files by default
- **Lightweight Core** - Simple implementation with minimal dependencies

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

4. Toggle sidebar for note management:

   ```
   :NoteFloatSidebar
   ```

5. Get a summary of your current note:

   ```
   :NoteFloatSummarize
   ```

6. Initialize Git repository for syncing:

   ```
   :NoteFloatGitInit
   ```

7. Manually sync notes to Git:
   ```
   :NoteFloatGitSync
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

-- Toggle sidebar
vim.keymap.set('n', '<Leader>ns', '<cmd>NoteFloatSidebar<CR>', { desc = 'Toggle notes sidebar' })

-- Summarize current note
vim.keymap.set('n', '<Leader>nz', '<cmd>NoteFloatSummarize<CR>', { desc = 'Summarize note' })

-- Git sync
vim.keymap.set('n', '<Leader>ng', '<cmd>NoteFloatGitSync<CR>', { desc = 'Sync notes to Git' })
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

  -- Periodic save (for crash protection)
  periodic_save = true,
  periodic_save_interval = 60000, -- 1 minute

  -- Git synchronization
  git_sync = false, -- Disabled by default
  git_sync_interval = 300000, -- 5 minutes
  git_sync_message = "Auto-sync NoteFloat notes",

  -- AI summarization
  summarize_prompt = "Summarize the following note in 3 bullet points:\n\n",

  -- Sidebar configuration
  sidebar_width = 30,

  -- Available note categories
  categories = {"quick", "todo", "code", "meeting", "project"}
})
```

## Advanced Features

### Git Synchronization

To sync your notes with a Git repository:

1. Initialize a Git repository in your notes directory:

   ```
   :NoteFloatGitInit
   ```

   This will create a Git repository and prompt you for an optional remote URL.

2. Enable automatic Git sync in your config:

   ```lua
   require("notefloat").setup({
     git_sync = true
   })
   ```

3. Manually sync at any time:
   ```
   :NoteFloatGitSync
   ```

### AI-Powered Note Summarization

If you have the OpenAI CLI installed and configured, NoteFloat can generate summaries of your notes:

1. Install the OpenAI CLI:

   ```
   pip install openai
   ```

2. Configure your API key:

   ```
   export OPENAI_API_KEY=your_api_key_here
   ```

3. Summarize your current note:
   ```
   :NoteFloatSummarize
   ```

If the OpenAI CLI is not available, a basic statistical summary will be provided instead.

### Multi-Window Management

Toggle the sidebar to see and switch between different note categories:

```
:NoteFloatSidebar
```

In the sidebar:

- Press `Enter` to open the selected note category
- Press `q` to close the sidebar

## Storage

Notes are saved in your Neovim data directory:

- Linux: `~/.local/share/nvim/notefloat/`
- macOS: `~/Library/Application Support/nvim/notefloat/`
