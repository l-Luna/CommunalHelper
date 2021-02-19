module CommunalHelperZipLine

using ..Ahorn, Maple

@mapdef Entity "CommunalHelper/ZipLine" ZipLine(x::Integer, y::Integer, 
                                                splinePath::Bool = false,
                                                nodes::Array{Tuple{Integer, Integer}, 1}=Tuple{Integer, Integer}[])

const placements = Ahorn.PlacementDict(
    "Zip Line (Lines Path) (Communal Helper)" => Ahorn.EntityPlacement(
        ZipLine,
		"line"
    ),
    "Zip Line (Spline Path) (Communal Helper)" => Ahorn.EntityPlacement(
        ZipLine,
		"line",
        Dict{String, Any}(
            "splinePath" => true
        )
    )
)

Ahorn.nodeLimits(entity::ZipLine) = 1, -1

function Ahorn.selection(entity::ZipLine)
    x, y = Ahorn.position(entity)

    res = [Ahorn.Rectangle(x - 2, y - 2, 12, 12)]
	
	for node in get(entity.data, "nodes", ())
        nx, ny = Int.(node)
		
		push!(res, Ahorn.Rectangle(nx + floor(Int, 5) - 6, ny + floor(Int, 5) - 6, 10, 10))
	end
	
	return res
end

function Ahorn.renderAbs(ctx::Ahorn.Cairo.CairoContext, entity::ZipLine, room::Maple.Room)
    x, y = Ahorn.position(entity)
	px, py = x, y
	
	# Iteration through all the nodes
	for node in get(entity.data, "nodes", ())
        nx, ny = Int.(node)
		cx, cy = px + 5, py + 5
		cnx, cny = nx + 5, ny + 5

		length = sqrt((px - nx)^2 + (py - ny)^2)
		theta = atan(cny - cy, cnx - cx)

		Ahorn.Cairo.save(ctx)

		Ahorn.translate(ctx, cx, cy)
		Ahorn.rotate(ctx, theta)

		Ahorn.setSourceColor(ctx, (0.0, 0.0, 1.0, 1.0))
		Ahorn.set_antialias(ctx, 1)
		Ahorn.set_line_width(ctx, 1);

		# Offset for rounding errors
		Ahorn.move_to(ctx, 0, 4 + (theta <= 0))
		Ahorn.line_to(ctx, length, 4 + (theta <= 0))

		Ahorn.move_to(ctx, 0, -4 - (theta > 0))
		Ahorn.line_to(ctx, length, -4 - (theta > 0))

		Ahorn.stroke(ctx)

		Ahorn.Cairo.restore(ctx)
		
	    Ahorn.drawRectangle(ctx, nx - 1, ny - 1, 10, 10, (0.3, 0.7, 0.2, 1.0))
		
		px, py = nx, ny
	end
	
	Ahorn.drawRectangle(ctx, x - 2, y - 2, 12, 12, (0.0, 0.0, 0.0, 1.0))
end

end