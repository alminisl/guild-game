-- Test paper rendering to verify 9-slice implementation
local UIAssets = require("ui.ui_assets")

function love.load()
    UIAssets.preloadAll()
    print("Paper test loaded")
end

function love.draw()
    -- Draw a large test panel
    love.graphics.clear(0.2, 0.2, 0.25)
    
    -- Test RegularPaper at different sizes
    UIAssets.drawPaper(50, 50, 300, 200, {
        special = false,
        color = {1, 1, 1, 1},
        alpha = 1
    })
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Regular Paper 300x200", 60, 60)
    
    -- Test larger size
    UIAssets.drawPaper(400, 50, 500, 300, {
        special = false,
        color = {1, 1, 1, 1},
        alpha = 1
    })
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Regular Paper 500x300", 410, 60)
    
    -- Test SpecialPaper
    UIAssets.drawPaper(50, 300, 400, 250, {
        special = true,
        color = {1, 1, 1, 1},
        alpha = 1
    })
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Special Paper 400x250", 60, 310)
    
    -- Draw grid overlay to show 64px sections
    love.graphics.setColor(1, 0, 0, 0.3)
    for i = 0, 10 do
        love.graphics.line(50 + i * 64, 50, 50 + i * 64, 250)
        love.graphics.line(50, 50 + i * 64, 350, 50 + i * 64)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
