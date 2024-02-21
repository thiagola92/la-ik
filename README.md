# LaIK
Inverse Kinematic addon for Godot.

# Usage

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

# Good and Bad
Good:
- Scaling only one of the axis negatively works

Bad:
- Probably slower than Godot IK
	- Written in GDScript
	- Create [Polygon2D](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html) to represent bone shapes
- Only contains logic of
	- [SkeletonModification2DLookAt](https://docs.godotengine.org/en/stable/classes/class_skeletonmodification2dlookat.html)
	- [SkeletonModification2DTwoBonesIK](https://docs.godotengine.org/en/stable/classes/class_skeletonmodification2dtwoboneik.html)
	- [SkeletonModification2DCCDIK](https://docs.godotengine.org/en/stable/classes/class_skeletonmodification2dccdik.html)
- No integration with Godot default nodes
	- Can't add skeleton to [Polygon2D.skeleton](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html#class-polygon2d-property-skeleton)
 
# Why
(11-dez-2023) After a long time reading Godot inverse kinematic and trying to fix ([#83397][1], [#83330][2], [#81544][3], [#81051][4], [#81048][5]), I started questioning myself if my changes were correct ([comment][6]).  

So I started rewriting in GDScript to get a better knowledge of the logic! The difference is that I'm copying logic that makes sense to me and removing anything that I don't understand why exists (and writing my own logic).

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
- [Alan Zucconi](https://www.alanzucconi.com/2018/05/02/ik-2d-1/) for logic behind Two Bones IK.
- [Ryan Jucket](https://www.ryanjuckett.com/cyclic-coordinate-descent-in-2d/) for logic behind CCDIK.
