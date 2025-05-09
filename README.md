# tmp-edit.nvim

This plugin copies a file to the system's temporary directory ($TMPDIR or \tmp)
for editing, helping reduce input lag when editing files on remote mounts (e.g.,
sshfs). The file is synced each time the file is saved back to its original path.

This is useful if you are mounting a file-system using sshfs and you want to edit
without using ssh, which allows system wide clipboard, configration etc. The
main reason is that as sshfs uses ssh as backend, it is slow, causing input lags
and jitters even in the lightest of editors.

There are two main functions, `start_edit_in_tmp` which copies the current file
to `$TMPDIR` and sets it to the buffer. Each time this file is written, the
changes are synced back to the original file.

`stop_edit_in_tmp` changes the buffer back to the original file.

One can use `toggle_edit_in_tmp` to toggle the above functions for ease.

## Note

This plugin is in active development and may not work as intended, do not use it
for critical files. If doing so, make sure to create backups.

This plugin simply copies the written file back to the original file, if there are
changes in the original file while in tmp-edit, the changes **WILL** be overwritten.

This plugin restarts the LSPs for editing the temp file to prevent errors and lags
when the LSPs is set to the sshfs mounted path.

There is a issue with using LSPs for **different languages** which may conflict with
the editing of temp file, when they are in the same neovim instance. Editing more
than one file in a instance causes a debug message to pop up. However, it dose not
seem to affect the usage of the plugin.

## Installation

To install and add the keymaps in using [lazy.nvim](https://lazy.folke.io/)

```lua
return {
  "GeordyJ/tmp-edit.nvim",
  lazy = true,
  opts = {
    -- See Configuration for details
  },
  keys = {
    {
      "<leader>gt", --change it to your liking
      function()
        require("tmp-edit").toggle_edit_in_tmp() -- or use start_edit_in_tmp and stop_edit_in_tmp
      end,
      desc = "Toggle Temp Edit",
    },
  },
}
```

## Configuration

The default options are shown below.

```lua
  opts = {
    verbose = true,
    set_timestep = true,
    delete_temporary_file = false,
    tmp_dir = os.getenv("TMPDIR") or "/tmp",
  },

```
