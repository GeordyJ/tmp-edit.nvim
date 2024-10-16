# tmp-edit.nvim

This plugin copies a file to the system's temporary directory ($TMPDIR or \tmp)
for editing, helping reduce input lag when editing files on remote mounts (e.g.,
sshfs). The file is synced each time the file is saved back to its original path.

This is useful if you are mounting a filesystem using sshfs and you want to edit
without using ssh, which allows system wide clipboard, configration etc. The
main reason is that as sshfs uses ssh as backend, it is slow, causing input lags
and jitters even in the lightest of editors.

There are two main functions, `start_edit_in_tmp` which copies the current file
to $TMPDIR and sets it to the buffer. Each time this file is written, the
changes are synced back to the original file.

`stop_edit_in_tmp` changes the buffer back to the original file.

## Note

This plugin is in active development and may not work as intended, do not use it
for critical files.

This plugin restarts the LSPs for editing the tmp-file to prevent errors and lags
when the LSPs is set to the sshfs mounted path. The LSPs works fine but it may
not carry the user LSP config and instead use the default config.

This plugin simply copys the written file back to the orignal file, if there are
changes in the orignal file while in tmp-edit, the changes **WILL** be overwritten.

## Installation

To install and add the keyamps in using lazy.nvim

```lua
return {
  "GeordyJ/tmp-edit.nvim",
  lazy = true, -- Lazy loading, activate plugin with keymap

  config = function(_, opts)
    require("tmp-edit").setup({ verbose = false }) --default
  end,
  keys = {
    {
      "<leader>gt",
      function()
        require("tmp-edit").start_edit_in_tmp()
      end,
      desc = "Start Temp Edit",
    },
    {
      "<leader>go",
      function()
        require("tmp-edit").stop_edit_in_tmp()
      end,
      desc = "Stop Temp Edit",
    },
  },
}
```
