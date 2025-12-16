# winctrl.nvim

Interactive window resize mode for Neovim with visual direction hints.

`winctrl.nvim` lets you temporarily enter a resize mode where keys
(e.g. `h/j/k/l`) resize the current window and small floating hints show
available directions. The mode exits automatically when focus changes
or on explicit quit keys.

---

## Features

- Interactive resize mode
- Visual floating direction hints
- Fully configurable keys, symbols, border style, and step size
- Buffer-local mappings only while active

---

## LazyVim

```lua
return {
  {
    name = "TadaEXE/winctrl.nvim",
    opts = {
      step = 4,
      border = "single",
      symbols = { up = "▲", down = "▼", left = "◀", right = "▶" },
      keys = {
        left = "h",
        right = "l",
        up = "k",
        down = "j",
        quit = "q",
        esc = "<Esc>",
      },
      notify = true,
    },
  },
}
```

---

## Command

```
:WinCtrl
```

