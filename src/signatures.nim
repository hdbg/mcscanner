# import strenc
import std/[sets, tables]

const
  general* = {
    "aimbot" : ["aimbot", "killaura", "aimassist"].toHashSet,
    "esp": ["wallhack"].toHashSet
  }.toTable

  forgehax* = {
    "aimbot": @["dev.fiki.forgehax.main.mods.combat.Aimbot"].toHashSet,
    "fly": @[
      "dev/fiki/forgehax/asm/events/movement/ElytraFlyMovementEvent.classPK", 
      "dev/fiki/forgehax/main/mods/player/PacketFlyMod.classPK",
      "dev/fiki/forgehax/main/mods/player/ElytraFlight$FlyMode.classPK",
      "dev/fiki/forgehax/main/mods/player/VanillaFlyMod.classPK",
      "dev/fiki/forgehax/main/mods/player/BoatFly.classPK"
    ].toHashSet,
    "autoeat": @[
      "/dev/fiki/forgehax/main/mods/player/AutoEatMod.class",
      "dev/fiki/forgehax/main/mods/player/AutoEatMod",
      "dev.fiki.forgehax.main.mods.player.AutoEatMod",
    ].toHashSet
  }.toTable

  baritone* = {
    "commands": @[
      "/baritone/command",
      "/baritone/command/defaults",
      "/baritone/command/defaults/FollowCommand.class",
      "baritone/command/defaults/FollowCommand"
    ].toHashSet,
    "mixins": @[
      "baritone.launch.mixins.MixinEntity",
      "baritone/launch/mixins/MixinEntityRenderManager",
      "baritone/launch/mixins/MixinLivingEntity",
      "baritone/launch/mixins/MixinPlayerController",
      "baritone/launch/mixins/MixinWorldRenderer",
    ].toHashSet
    
  }.toTable

  allSigs* = {"forgehax":forgehax, "baritone":baritone, "general":general}.toTable