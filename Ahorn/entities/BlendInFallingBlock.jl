module CommunalHelperBlendInFallingBlock
using ..Ahorn, Maple

@mapdef Entity "CommunalHelper/BlendInFallingBlock" BlendInFallingBlock(
								x::Integer, y::Integer, 
								width::Integer = 8, 
								height::Integer = 8,
								tiletype::String = "3",
                                behind::Bool = false, climbFall::Bool = true)
								
const placements = Ahorn.PlacementDict(
	"Blend In Falling Block (Communal Helper)" => Ahorn.EntityPlacement(
		BlendInFallingBlock,
		"rectangle",
		Dict{String, Any}(),
		Ahorn.tileEntityFinalizer
	)
)

Ahorn.editingOptions(entity::BlendInFallingBlock) = Dict{String, Any}(
	"tiletype" => Ahorn.tiletypeEditingOptions()
)

Ahorn.minimumSize(entity::BlendInFallingBlock) = 8, 8
Ahorn.resizable(entity::BlendInFallingBlock) = true, true

Ahorn.selection(entity::BlendInFallingBlock) = Ahorn.getEntityRectangle(entity)

Ahorn.renderAbs(ctx::Ahorn.Cairo.CairoContext, entity::BlendInFallingBlock, room::Maple.Room) = Ahorn.drawTileEntity(ctx, room, entity, blendIn = true)

end
