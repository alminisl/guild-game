-- LÖVE configuration file
-- This runs before love.load()

function love.conf(t)
    t.window.title = "Guild Management"
    t.window.width = 1920
    t.window.height = 1080
    t.window.resizable = true
    t.window.minwidth = 1280
    t.window.minheight = 720
    t.window.vsync = 1

    -- Graphics settings for crisp rendering
    t.window.msaa = 0  -- Disable antialiasing for pixel-crisp rendering
end
