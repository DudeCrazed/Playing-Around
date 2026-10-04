-- PARABOUND: original data-driven combat and campaign definitions.
local C = {}
C.Version = 1
C.Weapons = {
 Longblade={Damage=12,Range=8,Startup=.30,Recovery=.32,Knockback=28,Color=Color3.fromRGB(196,212,225)},
 TwinFangs={Damage=8,Range=6,Startup=.20,Recovery=.22,Knockback=20,Color=Color3.fromRGB(162,217,214)},
 Greatblade={Damage=20,Range=10,Startup=.52,Recovery=.60,Knockback=45,Color=Color3.fromRGB(205,173,111)},
 Spear={Damage=11,Range=13,Startup=.36,Recovery=.40,Knockback=30,Color=Color3.fromRGB(186,203,191)},
 Gauntlets={Damage=10,Range=5,Startup=.22,Recovery=.26,Knockback=34,Color=Color3.fromRGB(185,138,100)},
 ChainScythe={Damage=13,Range=11,Startup=.42,Recovery=.45,Knockback=25,Color=Color3.fromRGB(164,140,186)},
 Arcstaff={Damage=10,Range=10,Startup=.34,Recovery=.34,Knockback=24,Color=Color3.fromRGB(124,194,218)},
 Bowblade={Damage=9,Range=16,Startup=.38,Recovery=.40,Knockback=23,Color=Color3.fromRGB(206,197,149)},
}
C.WeaponOrder={'Longblade','TwinFangs','Greatblade','Spear','Gauntlets','ChainScythe','Arcstaff','Bowblade'}
C.Schools={
 Ember={Color=Color3.fromRGB(244,122,67),Abilities={'Cinder Lance','Furnace Ring','Sunfall'}},
 Gale={Color=Color3.fromRGB(134,224,206),Abilities={'Windcut','Slipstream','Tempest'}},
 Stone={Color=Color3.fromRGB(204,176,131),Abilities={'Faultline','Stoneward','Mountainfall'}},
 Tide={Color=Color3.fromRGB(101,176,232),Abilities={'Undertow','Restoring Rain','Tidal Crown'}},
 Lumen={Color=Color3.fromRGB(247,225,157),Abilities={'Prism Bolt','Radiant Aegis','Daybreak'}},
 Umbral={Color=Color3.fromRGB(178,135,233),Abilities={'Shadow Thread','Phase Step','Night Chorus'}},
}
C.SchoolOrder={'Ember','Gale','Stone','Tide','Lumen','Umbral'}
C.MainWeapons={'Longblade','TwinFangs','Spear','Greatblade'}
C.Maps={'Terrace Bellcourt','Scarwood Crossing','Emberforge Bridge'}
C.Audio={Music=9041782366,Parry=9125594716,PerfectParry=9119447936,Hit=9116653976,Tell=9125594711}
C.Weapons.Longblade.Startup=.16;C.Weapons.Longblade.Recovery=.20;C.Weapons.Longblade.Range=7;C.Weapons.Longblade.Damage=10
C.Weapons.TwinFangs.Startup=.12;C.Weapons.TwinFangs.Recovery=.17;C.Weapons.TwinFangs.Range=6;C.Weapons.TwinFangs.Damage=7
C.Weapons.Spear.Startup=.20;C.Weapons.Spear.Recovery=.23;C.Weapons.Spear.Range=9;C.Weapons.Spear.Damage=11
C.Weapons.Greatblade.Startup=.30;C.Weapons.Greatblade.Recovery=.35;C.Weapons.Greatblade.Range=7.5;C.Weapons.Greatblade.Damage=15
C.Schools.Ember.Abilities={'Resonance Cut'}
-- Shared by server validation and the client HUD. Light attacks are the core verb and stay free;
-- regeneration must sustain ordinary heavy/dash use across a 3-stock duel.
C.ResonanceCosts={Light=0,Heavy=10,Dash=8,Arcana1=24}
C.ResonanceRegen=6
return C
