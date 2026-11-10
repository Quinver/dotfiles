local sound_dir = "/home/quinver/.config/nvim/lua/plugins/"

vim.pack.add({
  {
    src = "https://github.com/whleucka/reverb.nvim",
    name = "reverb",
  }
})

-- Scan sound_dir for *.wav files, sorted oldest -> newest by mtime
local function get_wav_files_chronological(dir)
  local files = {}
  local handle = vim.uv.fs_scandir(dir)
  if handle then
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if ftype == "file" and name:match("%.wav$") then
        local stat = vim.uv.fs_stat(dir .. name)
        table.insert(files, { path = dir .. name, mtime = stat and stat.mtime.sec or 0 })
      end
    end
  end
  table.sort(files, function(a, b) return a.mtime < b.mtime end)
  local paths = {}
  for _, f in ipairs(files) do
    table.insert(paths, f.path)
  end
  return paths
end

require("reverb").setup({
  player = "mpv",
  max_sounds = 20,
  sounds = {
    CursorMovedI = { path = get_wav_files_chronological(sound_dir), volume = 100 },
  },
})
