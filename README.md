# la-ik
Inverse Kinematic addon for Godot.

# Installation
- Download latest release
- Extract `addons` directory from ZIP
- Move `addons` directory to your project directory
  - If your project already have an `addons` directory, copy `addons/la_ik` to your project `addons`
- Open Godot project
- Go to `Project > Project Settings... > Plugins`
  - You should be seeing LaIK plugin there, otherwise something was done wrong
- Check `Enable` in LaIK plugin
- Restart Godot

# Why
(11-dez-2023) After a long time reading Godot inverse kinematic and trying to fix ([#83397][1], [#83330][2], [#81544][3], [#81051][4], [#81048][5]), I started questioning myself if my changes were correct ([comment][6]).  

So I started rewriting in GDScript to get a better knowledge of the logic! The difference is that I'm copying logic that makes sense to me and remove anything that I don't understand why exists (and writing my own logic).

This could be a bad decision, but rewriting will give me a better idea of the problem and solutions.

[1]: https://github.com/godotengine/godot/pull/83397
[2]: https://github.com/godotengine/godot/pull/83330
[3]: https://github.com/godotengine/godot/pull/81544
[4]: https://github.com/godotengine/godot/pull/81051
[5]: https://github.com/godotengine/godot/pull/81048
[6]: https://github.com/godotengine/godot/pull/83330#issuecomment-1809000653

# Credits
- [Godot](https://godotengine.org/) for most of the code logic.
- [TwistedTwigleg](https://github.com/TwistedTwigleg) for writing IK for Godot.
- [Alan Zucconi](https://www.alanzucconi.com/2018/05/02/ik-2d-1/) for logic behind IK.
