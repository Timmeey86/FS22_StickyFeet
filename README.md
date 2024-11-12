# FS25_StickyFeet

## Mod description

This mod makes your feet stick to moving vehicles/trailers/implements so you no longer slide off while they are being driven by the AI or another player.

The possibilities which are opened up by this still need to be explored, but some are:
- Carrying your friends to the workplace in the back of a pickup truck or a trailer
- Slowly driving across a field with small bales with a second player bringing them to the trailer and a third stacking them
- Streamers can film from angles which are otherwise impossible (while the AI is working the field)
- Stacking bales on a trailer in single player while letting the AI drive and using a baler which lifts bales up to the trailer

The following features currently work:
- Sticking to a moving trailer when the player is not moving
- Walking around on a moving trailer (same speed in every direction)
- Auto-rotating with the vehicle as it's turning (in first person view)
- Jumping while on a moving trailer (you'll move as fast as the vehicle)
- Jumping onto and off a trailer (your movement speed will not be affected by the vehicle, though)
- Jumping between vehicles

There are limitations, however:
- High vehicle speeds can cause issues with this mod
- High ping in multiplayer can cause issues, too
- Picking up and dropping objects will not work properly at high speeds.
- Other players (and the own player in third person view) are not being animated properly while moving on a moving trailer
- Moving around the borders of a vehicle or pallets can be buggy

## Videos

Since videos can best explain this mod:

[![Video showcasing jumping on vehicle](screenshots/Thumb1.png)](https://youtu.be/PySSWl_zaMY)

[![Video showcasing bale stacking](screenshots/Thumb2.png)](https://www.youtube.com/watch?v=JfD-vVAJN4w)

## How to install

TODO

## How to debug/code

1. Obviously, own a copy of Farming Simulator 25
1. Clone this folder anywhere
1. Use Visual Code with at least the Lua Language Server Plugin for coding
1. When testing, execute copytofs.bat and open that mod folder in Giants Studio
1. Debug in Giants Studio
