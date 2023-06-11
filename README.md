QNurbsEditor is a 2D curve editor based on NURBS, although the curves used are currently only uniform curves.

As special features it allows to load a raster as background to help tracing a given shape, and to load python scripts that would be invoked passing the evaluated curve as argument.

Said script has to implement a `def run(arg)` function, where arg is a map that can be unpacked like

```
    curve = arg["curve"]
    tangents = arg["tangents"]
    tangentAngles = arg["tangentAngles"]
```
