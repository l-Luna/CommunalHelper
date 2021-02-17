using Celeste.Mod.Entities;
using Microsoft.Xna.Framework;
using Monocle;
using MonoMod.Utils;
using System;
using System.Collections;

namespace Celeste.Mod.CommunalHelper.Entities {

    [CustomEntity("CommunalHelper/BlendInFallingBlock")]
    class BlendInFallingBlock : Solid {

        public bool Triggered;
        public float FallDelay;

        private char TileType;
        private TileGrid blendTiles, tiles;

        private bool climbFall;

        private Level level;

        private float outlineAlpha = 0f;

        public bool HasStartedFalling {
            get;
            private set;
        }

        public BlendInFallingBlock(Vector2 position, char tile, int width, int height, bool behind, bool climbFall)
            : base(position, width, height, safe: false) {
            this.climbFall = climbFall;
            Add(new Coroutine(Sequence()));
            TileType = tile;
            SurfaceSoundIndex = SurfaceIndex.TileToIndex[tile];
            if (behind) {
                base.Depth = 5000;
            }
        }

        public BlendInFallingBlock(EntityData data, Vector2 offset)
        : this(data.Position + offset, data.Char("tiletype", '3'), data.Width, data.Height, data.Bool("behind"), data.Bool("climbFall", defaultValue: true)) { }

        public override void Awake(Scene scene) {
            base.Awake(scene);
            level = SceneAs<Level>();
            Rectangle tileBounds = level.Session.MapData.TileBounds;

            int x = (int) (base.X / 8f) - tileBounds.Left;
            int y = (int) (base.Y / 8f) - tileBounds.Top;
            int w = (int) base.Width / 8;
            int h = (int) base.Height / 8;
            VirtualMap<char> levelTileTypes = new DynData<SolidTiles>(level.SolidTiles).Get<VirtualMap<char>>("tileTypes");
            VirtualMap<char> map = new VirtualMap<char>(w + 2, h + 2, '0');

            for (int i = -1; i < w + 1; i++) {
                for (int j = -1; j < h + 1; j++) {
                    bool edge = i == -1 || i == w || j == -1 || j == h;
                    map[i + 1, j + 1] = edge ? levelTileTypes[x + i, y + j] : TileType;
                }
            }

            blendTiles = GFX.FGAutotiler.GenerateMap(map, new Autotiler.Behaviour() {
                EdgesExtend = true, // <--- makes this falling block in need to be next to tile edges that are 2+ tiles thick
                EdgesIgnoreOutOfLevel = false,
                PaddingIgnoreOutOfLevel = false,
            }).TileGrid;

            tiles = GFX.FGAutotiler.GenerateBox(TileType, w, h).TileGrid;
            Add(new EffectCutout());
            base.Depth = -10501;
            blendTiles.Position -= Vector2.One * 8;
            Add(blendTiles);
            Add(new TileInterceptor(tiles, highPriority: true));
            if (CollideCheck<Player>()) {
                RemoveSelf();
            }
        }

        public override void Update() {
            base.Update();
            if (outlineAlpha > 0f)
                outlineAlpha = Calc.Approach(outlineAlpha, 0f, Engine.DeltaTime * 3f);
        }

        public override void Render() {
            base.Render();
            if (outlineAlpha > 0f) {
                Rectangle rect = new Rectangle((int) X, (int) Y, (int) Width, (int) Height);
                int infl = (int) Math.Round((1 - Ease.SineIn(outlineAlpha)) * 8);
                rect.Inflate(infl, infl);
                Draw.HollowRect(rect, Color.White * outlineAlpha);
            }
        }

        public override void OnShake(Vector2 amount) {
            base.OnShake(amount);
            tiles.Position += amount;
        }

        public override void OnStaticMoverTrigger(StaticMover sm) {
            Triggered = true;
        }

        private bool PlayerFallCheck() {
            if (climbFall) {
                return HasPlayerRider();
            }
            return HasPlayerOnTop();
        }

        private bool PlayerWaitCheck() {
            if (Triggered) {
                return true;
            }
            if (PlayerFallCheck()) {
                return true;
            }
            if (climbFall) {
                if (!CollideCheck<Player>(Position - Vector2.UnitX)) {
                    return CollideCheck<Player>(Position + Vector2.UnitX);
                }
                return true;
            }
            return false;
        }

        private IEnumerator Sequence() {
            while (!Triggered && !PlayerFallCheck()) {
                yield return null;
            }
            while (FallDelay > 0f) {
                FallDelay -= Engine.DeltaTime;
                yield return null;
            }
            HasStartedFalling = true;
            bool switchedTiles = false;
            while (true) {
                if(!switchedTiles) {
                    Remove(blendTiles);
                    Add(tiles);
                    switchedTiles = true;
                    level.Flash(Color.White * .12f, false);
                    level.Shake();
                    outlineAlpha = 1f;
                }
                ShakeSfx();
                StartShaking();
                Input.Rumble(RumbleStrength.Medium, RumbleLength.Medium);
                yield return 0.2f;
                float timer = 0.4f;
                while (timer > 0f && PlayerWaitCheck()) {
                    yield return null;
                    timer -= Engine.DeltaTime;
                }
                StopShaking();
                for (int i = 2; (float) i < Width; i += 4) {
                    if (Scene.CollideCheck<Solid>(TopLeft + new Vector2(i, -2f))) {
                        SceneAs<Level>().Particles.Emit(FallingBlock.P_FallDustA, 2, new Vector2(X + (float) i, Y), Vector2.One * 4f, (float) Math.PI / 2f);
                    }
                    SceneAs<Level>().Particles.Emit(FallingBlock.P_FallDustB, 2, new Vector2(X + (float) i, Y), Vector2.One * 4f);
                }
                float speed = 0f;
                float maxSpeed = 160f;
                while (true) {
                    Level level = SceneAs<Level>();
                    speed = Calc.Approach(speed, maxSpeed, 500f * Engine.DeltaTime);
                    if (MoveVCollideSolids(speed * Engine.DeltaTime, thruDashBlocks: true)) {
                        break;
                    }
                    if (Top > (float) (level.Bounds.Bottom + 16) || (Top > (float) (level.Bounds.Bottom - 1) && CollideCheck<Solid>(Position + new Vector2(0f, 1f)))) {
                        Collidable = (Visible = false);
                        yield return 0.2f;
                        if (level.Session.MapData.CanTransitionTo(level, new Vector2(Center.X, Bottom + 12f))) {
                            yield return 0.2f;
                            SceneAs<Level>().Shake();
                            Input.Rumble(RumbleStrength.Strong, RumbleLength.Medium);
                        }
                        RemoveSelf();
                        DestroyStaticMovers();
                        yield break;
                    }
                    yield return null;
                }
                ImpactSfx();
                Input.Rumble(RumbleStrength.Strong, RumbleLength.Medium);
                SceneAs<Level>().DirectionalShake(Vector2.UnitY, 0.3f);
                StartShaking();
                LandParticles();
                yield return 0.2f;
                StopShaking();
                if (CollideCheck<SolidTiles>(Position + new Vector2(0f, 1f))) {
                    break;
                }
                while (CollideCheck<Platform>(Position + new Vector2(0f, 1f))) {
                    yield return 0.1f;
                }
            }
            Safe = true;
        }

        private void LandParticles() {
            for (int i = 2; (float) i <= base.Width; i += 4) {
                if (base.Scene.CollideCheck<Solid>(base.BottomLeft + new Vector2(i, 3f))) {
                    SceneAs<Level>().ParticlesFG.Emit(FallingBlock.P_FallDustA, 1, new Vector2(base.X + (float) i, base.Bottom), Vector2.One * 4f, -(float) Math.PI / 2f);
                    float direction = ((!((float) i < base.Width / 2f)) ? 0f : ((float) Math.PI));
                    SceneAs<Level>().ParticlesFG.Emit(FallingBlock.P_LandDust, 1, new Vector2(base.X + (float) i, base.Bottom), Vector2.One * 4f, direction);
                }
            }
        }

        private void ShakeSfx() {
            if (TileType == '3') {
                Audio.Play("event:/game/01_forsaken_city/fallblock_ice_shake", base.Center);
            } else if (TileType == '9') {
                Audio.Play("event:/game/03_resort/fallblock_wood_shake", base.Center);
            } else if (TileType == 'g') {
                Audio.Play("event:/game/06_reflection/fallblock_boss_shake", base.Center);
            } else {
                Audio.Play("event:/game/general/fallblock_shake", base.Center);
            }
        }

        private void ImpactSfx() {
            if (TileType == '3') {
                Audio.Play("event:/game/01_forsaken_city/fallblock_ice_impact", base.BottomCenter);
            } else if (TileType == '9') {
                Audio.Play("event:/game/03_resort/fallblock_wood_impact", base.BottomCenter);
            } else if (TileType == 'g') {
                Audio.Play("event:/game/06_reflection/fallblock_boss_impact", base.BottomCenter);
            } else {
                Audio.Play("event:/game/general/fallblock_impact", base.BottomCenter);
            }
        }
    }
}
