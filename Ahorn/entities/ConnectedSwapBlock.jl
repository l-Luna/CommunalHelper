module CommunalHelperConnectedSwapBlock
using ..Ahorn, Maple

function swapFinalizer(entity)
    x, y = Ahorn.position(entity)

    width = Int(get(entity.data, "width", 8))
    height = Int(get(entity.data, "height", 8))

    entity.data["nodes"] = [(x + width, y)]
end

@mapdef Entity "CommunalHelper/ConnectedSwapBlock" ConnectedSwapBlock(
                            x::Integer, y::Integer,
                            width::Integer = Maple.defaultBlockWidth, 
                            height::Integer = Maple.defaultBlockWidth,
                            theme::String = "Normal")

const placements = Ahorn.PlacementDict(
    "Connected Swap Block ($theme) (Communal Helper)" => Ahorn.EntityPlacement(
        ConnectedSwapBlock,
        "rectangle",
        Dict{String, Any}(
            "theme" => theme
        ),
        swapFinalizer
    ) for theme in Maple.swap_block_themes
)

Ahorn.editingOptions(entity::ConnectedSwapBlock) = Dict{String, Any}(
    "theme" => Maple.swap_block_themes
)

Ahorn.nodeLimits(entity::ConnectedSwapBlock) = 1, 1

Ahorn.minimumSize(entity::ConnectedSwapBlock) = 16, 16
Ahorn.resizable(entity::ConnectedSwapBlock) = true, true

function Ahorn.selection(entity::ConnectedSwapBlock)
    x, y = Ahorn.position(entity)
    stopX, stopY = Int.(entity.data["nodes"][1])

    width = Int(get(entity.data, "width", 8))
    height = Int(get(entity.data, "height", 8))

    return [Ahorn.Rectangle(x, y, width, height), Ahorn.Rectangle(stopX, stopY, width, height)]
end

function getTextures(entity::ConnectedSwapBlock)
    theme = lowercase(get(entity, "theme", "normal"))

    if theme == "moon"
        return "objects/swapblock/moon/blockRed", 
               "objects/swapblock/moon/target", 
               "objects/swapblock/moon/midBlockRed00",
               "objects/CommunalHelper/connectedSwapBlock/moon/innerCornersRed"
    end

    return "objects/swapblock/blockRed", 
           "objects/swapblock/target", 
           "objects/swapblock/midBlockRed00",
           "objects/CommunalHelper/connectedSwapBlock/innerCornersRed"
end

function renderTrail(ctx, x::Number, y::Number, width::Number, height::Number, trail::String)
    tilesWidth = div(width, 8)
    tilesHeight = div(height, 8)

    for i in 2:tilesWidth - 1
        Ahorn.drawImage(ctx, trail, x + (i - 1) * 8, y + 2, 6, 0, 8, 6)
        Ahorn.drawImage(ctx, trail, x + (i - 1) * 8, y + height - 8, 6, 14, 8, 6)
    end

    for i in 2:tilesHeight - 1
        Ahorn.drawImage(ctx, trail, x + 2, y + (i - 1) * 8, 0, 6, 6, 8)
        Ahorn.drawImage(ctx, trail, x + width - 8, y + (i - 1) * 8, 14, 6, 6, 8)
    end

    for i in 2:tilesWidth - 1, j in 2:tilesHeight - 1
        Ahorn.drawImage(ctx, trail, x + (i - 1) * 8, y + (j - 1) * 8, 6, 6, 8, 8)
    end

    Ahorn.drawImage(ctx, trail, x + width - 8, y + 2, 14, 0, 6, 6)
    Ahorn.drawImage(ctx, trail, x + width - 8, y + height - 8, 14, 14, 6, 6)
    Ahorn.drawImage(ctx, trail, x + 2, y + 2, 0, 0, 6, 6)
    Ahorn.drawImage(ctx, trail, x + 2, y + height - 8, 0, 14, 6, 6)
end

# Gets rectangles from Solid Extensions
function getExtensionRectangles(room::Maple.Room)
    entities = filter(e -> e.name == "CommunalHelper/SolidExtension", room.entities)
    rects = []

    for e in entities
        push!(rects, Ahorn.Rectangle(
            Int(get(e.data, "x", 0)),
            Int(get(e.data, "y", 0)),
            Int(get(e.data, "width", 8)),
            Int(get(e.data, "height", 8))
        ))
    end
        
    return rects
end

# Checks for collision with an array of rectangles at specified tile position
function notAdjacent(entity::ConnectedSwapBlock, ox, oy, rects)
    x, y = Ahorn.position(entity)
    rect = Ahorn.Rectangle(x + ox + 4, y + oy + 4, 1, 1)

    for r in rects
        if Ahorn.checkCollision(r, rect)
            return false
        end
    end

    return true
end

function renderSwapBlock(ctx::Ahorn.Cairo.CairoContext, x::Number, y::Number, width::Number, height::Number, midResource::String, block::String, innerCorners::String, entity::ConnectedSwapBlock, room::Maple.Room)
    midSprite = Ahorn.getSprite(midResource, "Gameplay")
    
    tileWidth = div(width, 8)
    tileHeight = div(height, 8)
    
    rects = getExtensionRectangles(room)
    rx, ry = Ahorn.position(entity)
    rect = Ahorn.Rectangle(rx, ry, width, height)
	
	if !(rect in rects)
        push!(rects, rect)
    end

    for i in 1:tileWidth, j in 1:tileHeight
		drawX, drawY = (i - 1) * 8, (j - 1) * 8
		
        closedLeft = !notAdjacent(entity, drawX - 8, drawY, rects)
        closedRight = !notAdjacent(entity, drawX + 8, drawY, rects)
        closedUp = !notAdjacent(entity, drawX, drawY - 8, rects)
        closedDown = !notAdjacent(entity, drawX, drawY + 8, rects)
        completelyClosed = closedLeft && closedRight && closedUp && closedDown

        if completelyClosed
            
            if notAdjacent(entity, drawX + 8, drawY - 8, rects)
                # up right
                Ahorn.drawImage(ctx, innerCorners, x + drawX, y + drawY, 8, 0, 8, 8)

            elseif notAdjacent(entity, drawX - 8, drawY - 8, rects)
                # up left
                Ahorn.drawImage(ctx, innerCorners, x + drawX, y + drawY, 0, 0, 8, 8)

            elseif notAdjacent(entity, drawX + 8, drawY + 8, rects)
                # down right
                Ahorn.drawImage(ctx, innerCorners, x + drawX, y + drawY, 8, 8, 8, 8)

            elseif notAdjacent(entity, drawX - 8, drawY + 8, rects)
                # down left
                Ahorn.drawImage(ctx, innerCorners, x + drawX, y + drawY, 0, 8, 8, 8)

            else
                # entirely surrounded, fill tile
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 8, 8, 8, 8)

            end
        else 
            if closedLeft && closedRight && !closedUp && closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 8, 0, 8, 8)

            elseif closedLeft && closedRight && closedUp && !closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 8, 16, 8, 8)

            elseif closedLeft && !closedRight && closedUp && closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 16, 8, 8, 8)

            elseif !closedLeft && closedRight && closedUp && closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 0, 8, 8, 8)

            elseif closedLeft && !closedRight && !closedUp && closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 16, 0, 8, 8)

            elseif !closedLeft && closedRight && !closedUp && closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 0, 0, 8, 8)

            elseif !closedLeft && closedRight && closedUp && !closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 0, 16, 8, 8)

            elseif closedLeft && !closedRight && closedUp && !closedDown
                Ahorn.drawImage(ctx, block, x + drawX, y + drawY, 16, 16, 8, 8)
            end
        end
    end

    Ahorn.drawImage(ctx, midSprite, x + div(width - midSprite.width, 2), y + div(height - midSprite.height, 2))
end

function Ahorn.renderSelectedAbs(ctx::Ahorn.Cairo.CairoContext, entity::ConnectedSwapBlock, room::Maple.Room)
    sprite = get(entity.data, "sprite", "block")
    startX, startY = Int(entity.data["x"]), Int(entity.data["y"])
    stopX, stopY = Int.(entity.data["nodes"][1])

    width = Int(get(entity.data, "width", 32))
    height = Int(get(entity.data, "height", 32))

    frame, trail, mid, innerCorners = getTextures(entity)

    renderSwapBlock(ctx, stopX, stopY, width, height, mid, frame, innerCorners, entity, room)
    Ahorn.drawArrow(ctx, startX + width / 2, startY + height / 2, stopX + width / 2, stopY + height / 2, Ahorn.colors.selection_selected_fc, headLength=6)
end

function Ahorn.renderAbs(ctx::Ahorn.Cairo.CairoContext, entity::ConnectedSwapBlock, room::Maple.Room)
    sprite = get(entity.data, "sprite", "block")

    startX, startY = Int(entity.data["x"]), Int(entity.data["y"])
    stopX, stopY = Int.(entity.data["nodes"][1])

    width = Int(get(entity.data, "width", 32))
    height = Int(get(entity.data, "height", 32))

    frame, trail, mid, innerCorners = getTextures(entity)

    renderTrail(ctx, min(startX, stopX), min(startY, stopY), abs(startX - stopX) + width, abs(startY - stopY) + height, trail)
    renderSwapBlock(ctx, startX, startY, width, height, mid, frame, innerCorners, entity, room)
end

end